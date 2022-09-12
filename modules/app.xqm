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

declare variable $app:cache-name := "releasecache";
declare variable $app:cache := cache:create($app:cache-name, map { "maximumSize": 1000, "expireAfterAccess": 1800 });

declare %templates:wrap function app:dyn-nav-li($node as node(), $model as map(*)) {
    ()
};

declare function app:get-softs(){
    doc($config:app-root||"/softs.xml")/*
};

declare %templates:wrap function app:releases($node as node(), $model as map(*)) {
    <div>
        <h1>JMMC's applications and services releases</h1>
        <p>Please find below public and beta links to run our Java applications (JAR or JavaWebStart) , get release notes, credits, details...</p>
        {app:release-table()}
    </div>
};

declare function app:json-doc($href as xs:string)
{
    let $key := data($href)
    let $val := cache:get($app:cache-name, $key)
    return
        if(exists($val)) then $val
        else
            let $val := json-doc($href)
            let $store := cache:put($app:cache-name, $key, $val)
            let $log := util:log("info", "get " || $href)
            return $val
};

declare function app:doc($href as xs:string)
{
    let $key := data($href)
    let $val := cache:get($app:cache-name, $key)
    return
        if(exists($val)) then $val
        else
            let $val := doc($href)
            let $store := cache:put($app:cache-name, $key, $val)
            let $log := util:log("info", "get " || $href)
            return $val
};

declare function app:release-table(){
    <table class="table table-light table-bordered align-middle">
        <thead>
            <tr><th></th><th>Application</th><th>Release page</th><th>Version</th><th>Release date</th></tr>
        </thead>
        <tbody>
        {
            let $colspan := 5 return (
            <tr><th colspan="{$colspan}" class="text-center">Java applications</th></tr>
            ,for $jnlp in app:get-softs()//jnlp
                let $name := $jnlp/name
                let $server-url := $jnlp/ancestor::server/url
                let $release := $jnlp/release[1]
                let $href := $server-url || $release/location  || $name ||".jnlp"
                let $firstjnlp := app:doc($href)
                let $icon := if($firstjnlp//*:icon/@href) then <img width="64" height="64" src="{($firstjnlp//*:icon/@href)[1]}" alt="Logo"/> else ()
                let $trs :=
                    for $release in $jnlp/release[not(status="dev")]
                        return
                        try{
                            let $location := $server-url || $release/location
                            let $r := app:doc( $location || 'ApplicationRelease.xml')
                            return
                                <tr>
                                {
                                    for $td in (<a href="{$location}">{data($release/status)}</a>,data($r//program/@version), data($r//pubDate)[1])
                                    return <td>{$td}</td>
                                }
                                </tr>
                        } catch * {
                            ()
                        }
                order by lower-case($name)
                return
                (
                    <tr><td rowspan="{count($trs)+1}" class="text-center">{$icon}</td><td rowspan="{count($trs)+1}" class="text-center">{data($name)}</td><td/><td/><td/></tr>
                    , $trs
                )
            ,<tr><th colspan="{$colspan}" class="text-center">Python applications</th></tr>
            ,for $module in app:get-softs()//pypi/module
                let $location := <url>https://pypi.org/pypi/{$module}</url>
                let $json := app:json-doc(<url>https://pypi.org/pypi/{$module}/json</url>)
                let $last := $json?urls?*
                let $deployed := $last?upload_time
                let $version := replace(replace($last?filename, $module||"-",""),".tar.gz","")
                order by lower-case($module)
                return
                    <tr><td></td><td class="text-center">{data($module)}</td><td><a href="{$location}">public</a></td><td>{$version}</td><td>{$deployed}</td></tr>
            ,<tr><th colspan="{$colspan}" class="text-center">Web applications</th></tr>
            ,for $app in app:get-softs()//web/app
                let $name := data($app/name)
                let $icon := if($app/icon-url) then <img width="64" height="64" src="{$app/icon-url}" alt="Logo"/> else ()
                let $trs :=
                for $release in $app/release
                    let $status := $release/status
                    let $location := $release/location
                    return
                        <tr><td><a href="{$location}">{data($status)}</a></td><td></td><td></td></tr>
                order by lower-case($name)
                return (
                    <tr><td rowspan="{count($trs)+1}" class="text-center">{$icon}</td><td rowspan="{count($trs)+1}" class="text-center">{data($name)}</td><td/><td/><td/></tr>
                    ,$trs
                )
            ,for $app in app:get-softs()//exist/app
                let $name := data($app/name)
                let $icon := if($app/icon-url) then <img width="64" height="64" src="{$app/icon-url}" alt="Logo"/> else ()
                let $trs :=
                for $release in $app/release
                    let $status := $release/status
                    let $location := $release/location
                    let $repo := app:doc(<url>{$location}repo.xml</url>)
                    let $expath := app:doc(<url>{$location}expath-pkg.xml</url>)
                    let $deployed := data($repo//*:deployed)
                    let $version := $expath//@version || " " ||$repo//*:status
                    let $title := $expath//*:title
                    return
                        <tr title="{$title}"><td><a href="{$location}">{data($status)}</a></td><td>{$version}</td><td>{$deployed}</td></tr>
                order by lower-case($name)
                return (
                    <tr><td rowspan="{count($trs)+1}" class="text-center">{$icon}</td><td rowspan="{count($trs)+1}" class="text-center">{data($name)}</td><td/><td/><td/></tr>
                    ,$trs
                )

        )}
        </tbody>
    </table>
};