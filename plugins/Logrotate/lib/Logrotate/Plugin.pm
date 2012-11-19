package Logrotate::Plugin;
use strict;
use warnings;
use MT::Util qw( ts2epoch epoch2ts );
use Logrotate::Util qw( powercms_files_dir make_zip_archive
                        csv_new current_ts log2text utf8_off move_file );
sub _logrotate {
    my $do;
    my $plugin = MT->component( 'Logrotate' );
    require File::Spec;
    my $basename = 'systemlog';
    my $dir = File::Spec->catdir( powercms_files_dir(), 'logrotate' );
    my $systemlog = File::Spec->catfile( $dir, $basename );
    require MT::Log;
    my $compress = $plugin->get_config_value( 'compress' );
    my $days_ago = $plugin->get_config_value( 'days_ago' );
    my $age = $plugin->get_config_value( 'age' );
    my $ext = '.csv';
    $ext .= '.zip' if ( $compress );
    my $sec = $days_ago * 86400;
    my $now = current_ts();
    $now = ts2epoch( undef, $now );
    $sec = $now - $sec;
    my $ts = epoch2ts( undef, $sec );
    my @logs = MT->model( 'log' )->load( { class => '*' }, {
                                           sort => 'created_on',
                                           start_val => $ts,
                                           direction => 'descend', } );
    if (! scalar @logs ) {
        return;
    }
    my $csv = csv_new();
    my $columns = MT->model( 'log' )->column_names;
    if ( $csv->combine( @$columns ) ) {
        my $string = $csv->string;
        $string = utf8_off( $string );
        $string = MT::I18N::encode_text( $string, 'utf8', 'cp932' );
        log2text( $string, $systemlog );
        $do = 1;
    }
    for my $log ( @logs ) {
        my @values;
        for my $column ( @$columns ) {
            my $val = $log->$column;
            if ( $column =~ /_on$/ ) {
                $val = "\t$val";
            } elsif ( $column eq 'level' ) {
                $val = int2level( $val );
            }
            push @values, $val;
        }
        if ( $csv->combine( @values ) ) {
            my $string = $csv->string;
            $string = utf8_off( $string );
            $string = MT::I18N::encode_text( $string, 'utf8', 'cp932' );
            log2text( $string, $systemlog );
            $do = 1;
        }
    }
    return 1 unless $do;
    my $start;
    if ( $age ) {
        my $last_log = File::Spec->catfile( $dir, $basename . '_' . $age . $ext );
        if (-f $last_log ) {
            unlink $last_log;
        }
        $start = $age - 1;
    } else {
        opendir DIR, $dir;
        my @files = grep { !m/^(\.|\.\.)$/g } readdir DIR;
        close DIR;
        for my $f ( @files ) {
            if ( $f =~ /_([0-9])*\./ ) {
                if (! $start ) {
                    $start = $1;
                } else {
                    $start = $1 if $1 > $start;
                }
            }
        }
    }
    for ( my $i = $start; $i >= 1; $i-- ) {
        my $j = $i + 1;
        my $log_old = File::Spec->catfile( $dir, $basename . '_' . $i . $ext );
        my $log_new = File::Spec->catfile( $dir, $basename . '_' . $j . $ext );
        if (-f $log_old ) {
            move_file( $log_old, $log_new );
        }
    }
    my $latest = File::Spec->catfile( $dir, $basename . $ext );
    my $next = File::Spec->catfile( $dir, $basename . '_1' . $ext );
    if (-f $latest ) {
        move_file( $latest, $next );
    }
    move_file( $systemlog, $systemlog . '.csv' );
    if ( $compress ) {
        make_zip_archive( $systemlog . '.csv', $latest );
        unlink $systemlog . '.csv';
    }
    for my $log ( @logs ) {
        $log->remove or die $log->errstr;
    }
    my $driver = MT->config( 'ObjectDriver' );
    return 1 if $driver ne 'DBI::mysql';
    require MT::Object;
    my $handle = MT::Object->driver->rw_handle;
    my $table = 'mt_log';
    my $sql = 'OPTIMIZE TABLE `' . $table . '`';
    $handle->do( $sql );
    return 1;
}

sub int2level {
    my $int = shift;
    return 'INFO'     if $int == 1;
    return 'WARNING'  if $int == 2;
    return 'ERROR'    if $int == 4;
    return 'SECURITY' if $int == 8;
    return 'DEBUG'    if $int == 16;
    return '';
}

1;