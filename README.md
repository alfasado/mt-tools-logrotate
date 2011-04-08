# About mt-logrotate for Movable Type

## Synopsis

The mt-logrotate script can be Logrotate MT's System Log from the command line or Cron.

## Getting Started

Confirm a directory called "powercms_files" was created under the MT root directory ( MT_HOME/powercms_files ), and was granted a writable permissions.

## Directives in mt-config.cgi

**Specify the path of "powercms_files" directory (include logrotate directory) anyware.**

    PowerCMSFilesDir /path/to/powercms_files

## Plugin Settings

    Compress(Logfile compress to zip) :
        Default value is 0 (require Archive::Zip)
    Log to csv older than(day(s)) :
        Default value is 7
    Log age :
        Default value is 5

## Example

Execute from the command line.

    cd /path/to/mt; perl ./tools/mt-logrotate

## Example - Executing from Cron

Execute logrotate once a day(at 2:00 am).

    0 2 * * * cd /path/to/mt; perl ./tools/mt-logrotate
