xquery version "3.0";

(:~
 : This module launches an XQuery script as a background job through
 : eXist-db's scheduler. The script is executed only once (not periodic).
 :
 : It requires the path to the script, a name to give to the job and optional
 : parameters specified as XML parameters expected by scheduler functions.
 :
 : @see scheduler:schedule-xquery-periodic-job
 :
 : A new job is started only if there is no job with the requested name
 : currently running.
 :
 : @note
 : This script must be run as database administrator as creation of scheduler
 : jobs is restricted to the dba role.
 :)
import module namespace scheduler="http://exist-db.org/xquery/scheduler";

(: the path to the script to execute :)
declare variable $resource external;

(: the name of the job to start :)
declare variable $name external;

(: the parameters to pass to the script :)
declare variable $params external;

let $ret :=
    if (scheduler:get-scheduled-jobs()//scheduler:job[@name=$name]) then
        <info>A job with the same name is already executing.</info>
    else if (scheduler:schedule-xquery-periodic-job($resource, 0, $name, $params, 0, 0)) then
        <info>Started new job.</info>
    else
        <error>Failed to start a new job.</error>
let $log := util:log(name($ret), data($ret))

return
    $ret
