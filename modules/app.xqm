xquery version "3.1";

(:~ This is the default application library module of the releases app.
 :
 : @author JMMC Tech Group
 : @version 1.0.0
 : @see https://www.jmmc.fr
 :)

(: Module for app-specific template functions :)
module namespace app="http://exist.jmmc.fr/releases/apps/releases/templates";
import module namespace templates="http://exist-db.org/xquery/html-templating";
import module namespace lib="http://exist-db.org/xquery/html-templating/lib";
import module namespace config="http://exist.jmmc.fr/releases/apps/releases/config" at "config.xqm";
import module namespace jmmc-dateutil="http://exist.jmmc.fr/jmmc-resources/dateutil";

declare variable $app:cache-name := "releasecache";
declare variable $app:cache-last-mods-key := "last-mod";
declare variable $app:cache-expire-delay-seconds := 120;
declare variable $app:cache-table-key := "whole-table";

declare %templates:wrap function app:dyn-nav-li($node as node(), $model as map(*)) {
    ()
};

declare function app:get-softs(){
    doc($config:app-root||"/softs.xml")/*
};

declare %templates:wrap function app:releases($node as node(), $model as map(*), $refresh as xs:string*) {
    <div>
        <h1>JMMC's applications and services releases</h1>
        <p>Please find below public and beta application links to run our Web, Python or Java applications (JAR or JavaWebStart), get release notes, credits, details...</p>
        {
            let $t := cache:get($app:cache-name, $app:cache-table-key)
            return
                if(exists($t)) then $t else app:release-table( empty($refresh) )
            ,
            let $last-mods := xs:dateTime(cache:get($app:cache-name, $app:cache-last-mods-key))
            let $delay := (current-dateTime() - $last-mods) div xs:dayTimeDuration('PT1S')
            let $plan-refresh := if( $delay > $app:cache-expire-delay-seconds )
                then
                    let $start-job := app:start-job($config:app-root || '/modules/update.xql', "update", map{})
                    return <span>&#160;🍃 this page was cached and is refreshing in background.</span>
                else ()
            return
                (<pre>Current date: {app:format-date(current-dateTime())} Generated on: {app:format-date($last-mods)}{$plan-refresh}</pre>)
        }
    </div>
};


declare function app:format-date($date){
    let $input := string($date)
    return
        <span title="{$input}">{
            if(contains($input, "-")) then
                substring($input, 1,16)
            else if ( contains($input, ",") ) then
                substring(string(jmmc-dateutil:RFC822toISO8601($input)), 1,16)
            else
                $input
        }</span>
};

declare function app:json-doc($href as xs:string, $use-cache as xs:boolean)
{
    let $key := data($href)
    let $val := cache:get($app:cache-name, $key)
    return
        if(exists($val) and $use-cache) then $val
        else
            let $log := util:log("info", "cache refreshed to get " || $href)
            let $val := json-doc($href)
            let $store := cache:put($app:cache-name, $key, $val)
            let $last-mods := cache:put($app:cache-name, $app:cache-last-mods-key, current-dateTime())
            return $val
};

declare function app:doc($href as xs:string,$use-cache as xs:boolean)
{
    let $key := data($href)
    let $val := cache:get($app:cache-name, $key)
    return
        if(exists($val) and $use-cache) then $val
        else
            let $log := util:log("info", "cache refreshed to get " || $href)
            let $val := try{doc($href)}catch *{util:log("info", "error getting " || $href),<e><program version="ERROR"/></e>}
            let $store := cache:put($app:cache-name, $key, $val)
            let $last-mods := cache:put($app:cache-name, $app:cache-last-mods-key, current-dateTime())
            return $val
};

declare function app:last-modified($href as xs:string,$use-cache as xs:boolean)
{
    let $header := "last-modified"
    let $key := data('head' || $href)
    let $val := cache:get($app:cache-name, $key)
    return
        if(exists($val) and $use-cache) then $val
        else
            let $log := util:log("info", "cache refreshed to get " || $href)
            let $val := hc:send-request(<hc:request method="head" href="{$href}"/>)//hc:*[@name=$header]/@value/string()
            let $store := cache:put($app:cache-name, $key, $val)
            let $last-mods := cache:put($app:cache-name, $app:cache-last-mods-key, current-dateTime())
            return $val
};


declare function app:release-table($use-cache as xs:boolean){
    let $apps := map:merge((
        for $jnlp in app:get-softs()//jnlp
            let $name := $jnlp/name
            let $server-url := $jnlp/ancestor::server/url
            let $firstjnlp-href := $server-url || $jnlp/release[1]/location  || $name ||".jnlp"
            let $firstjnlp := app:doc($firstjnlp-href, $use-cache)

            let $releases := for $release in $jnlp/release[not(status="dev")]
                    let $location := $server-url || $release/location
                    let $r := app:doc( $location || 'ApplicationRelease.xml', $use-cache)
                    let $version := data($r//program/@version)
                    let $jnlp-url := $location||$name||'.jnlp'
                    let $last-modified := app:last-modified($jnlp-url, $use-cache)
                    let $jar-url := $location||$name||"-"|| translate($version, " ", "") ||'.jar' (: try to mimic jar name format :)
                    let $version  := <div class="d-flex justify-content-between text-nowrap">
                        <span>{$version}</span>
                        <span><small>
                            <a  href="{$jnlp-url}">jnlp</a>&#160;
                            <a  href="{$jar-url}">jar</a>

                        </small></span>
                    </div>

                    return
                        map{$release/status : map{ "title": head(string($r//text)), "location":$location, "version": $version, "date":app:format-date($last-modified) } }
            let $icon-url := try { ($firstjnlp//*:icon/@href)[1] }catch * { () }
            return
                map { $name : map{ "category": "Java", "icon-url" : $icon-url, "releases": map:merge($releases) } }
        , for $module in app:get-softs()//pypi/module
                let $name := data($module)
                let $location := <url>https://pypi.org/pypi/{$name}</url>
                let $json := app:json-doc(<url>https://pypi.org/pypi/{$name}/json</url>, $use-cache)
                let $last := $json?urls?*
                let $deployed := app:format-date( $last?upload_time )
                let $version := replace(replace($last?filename, $module||"-",""),".tar.gz","")
                return
                    map{ $name : map{ "category": "Python", "releases": map{ "public": map{ "location":$location, "version":$version, "date":$deployed } } } }
        , for $repo in app:get-softs()//repos/*
                let $location := replace($repo/location, "/$","")
                let $category := $repo/category
                let $json  := if (name($repo)="github") then app:json-doc(replace($location, "github.com/", "api.github.com/repos/"), $use-cache) else ()
                let $name := $json?name
                let $json-release  := if (name($repo)="github") then app:json-doc(replace($location, "github.com/", "api.github.com/repos/")||"/releases", $use-cache)?*[1] else ()
                let $deployed := app:format-date( $json-release?created_at )
                let $version := $json-release?name
                let $title := $json?description
                return
                    map{ $name : map{"category": $category, "releases": map{ "public" : map{ "location":$location, "version":$version, "date":$deployed, "title":$title } } } }
        , for $app in app:get-softs()//web/app
            let $name := data($app/name)
            let $releases :=
            for $release in $app/release
                let $status := $release/status
                let $location := $release/location
                let $version := ()
                let $deployed := ()
                return
                    map{ $status : map{ "location":$location, "version":$version, "date":$deployed , "icon-url" : $app/icon-url} }
            return
                map { $name : map{ "category": "Web", "releases" : map:merge($releases) } }
        , for $app in app:get-softs()//exist/app
            let $name := data($app/name)
            let $releases :=
            for $release in $app/release
                let $status := $release/status
                let $location := $release/location
                let $repo := app:doc(<url>{$location}repo.xml</url>, $use-cache)
                let $expath := app:doc(<url>{$location}expath-pkg.xml</url>, $use-cache)
                let $deployed := app:format-date($repo//*:deployed)
                let $version := $expath//@version || " " ||$repo//*:status
                let $title := $expath//*:title
                return
                    map{ $status : map{ "title":$title, "location":$location, "version":$version, "date":$deployed } }
            return
                map { $name : map{ "category": "Web", "icon-url":$app/icon-url, "releases": map:merge($releases) } }
        ))

    return
    <table class="table table-light table-bordered align-middle table-striped">
        <thead>
            <tr><th></th><th>Application</th><th>Release page</th><th>Version</th><th>Release date</th></tr>
        </thead>
        <tbody>
        {   let $colspan := 5 return (
            for $name in map:keys($apps)
                let $app := map:get($apps, $name)
                group by $category := string($app?category)
                order by $category
                return
                (
                    <tr><th colspan="{$colspan}" class="text-center"><u>{$category} applications</u></th></tr>
                    , for $gname in $name order by $gname
                        let $gapp := map:get($apps, $gname)
                        let $icon := if ($gapp?icon-url) then <img width="64" height="64" src="{replace($gapp?icon-url,"http:","https:")}" alt="Logo"/>else ()
                        let $releases := $gapp?releases
                        let $title := head($releases?*?title)
                        let $names := map:keys($releases)
                        let $release-names := <ul class="list-unstyled">{for $n in $names let $r:= $releases($n) return <li><a title="{$r?title}" href="{$r?location}">{$n}</a></li>}</ul>
                        let $release-versions := <ul class="list-unstyled">{for $v in $releases?*?version return <li>{$v}</li>}</ul>
                        let $release-dates := <ul class="list-unstyled">{for $d in $releases?*?date return <li>{$d}</li>}</ul>
                        return
                            <tr title="{$title}"><td>{$icon}</td><td>{$gname}</td><td>{$release-names}</td><td>{$release-versions}</td><td>{$release-dates}</td></tr>
                )
        )}
        </tbody>
    </table>
};

declare function app:updates-remote-resources(){
    util:log("info", "app:updates-remote-resources()"),
    cache:put($app:cache-name ,$app:cache-table-key, app:release-table(false()))
};


declare %private function app:start-job($resource as xs:string, $name as xs:string, $params as map(*)) as xs:boolean {
    let $params := <parameters> {
        for $key in map:keys($params)
        return <param name="{ $key }" value="{ map:get($params, $key) }"/>
    } </parameters>

    let $log := util:log("info", "starting job : "|| $resource || " as " || $name )

    let $status := util:eval(xs:anyURI('schedule-job.xql'), false(), (
        xs:QName('resource'), $resource,
        xs:QName('name'),     $name,
        xs:QName('params'),   $params))
    return name($status) = 'success'
};
