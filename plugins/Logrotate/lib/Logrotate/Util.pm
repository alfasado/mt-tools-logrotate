package Logrotate::Util;
use strict;
use Exporter;
@Logrotate::Util::ISA = qw( Exporter );
use vars qw( @EXPORT_OK );
@EXPORT_OK = qw( powercms_files_dir make_zip_archive
                 csv_new current_ts log2text utf8_off move_file );

use MT::Util qw( offset_time_list );

use MT::Log;
use MT::FileMgr;
use File::Basename;
use File::Spec;

sub csv_new {
    my $csv = do {
    eval { require Text::CSV_XS };
    unless ( $@ ) { Text::CSV_XS->new ( { binary => 1 } ); } else
    { eval { require Text::CSV };
        return undef if $@; Text::CSV->new ( { binary => 1 } ); } };
    return $csv;
}

sub make_zip_archive {
    my ( $directory, $out, $files ) = @_;
    eval { require Archive::Zip } || return undef;
    my $archiver = Archive::Zip->new();
    my $fmgr = MT::FileMgr->new( 'Local' ) or die MT::FileMgr->errstr;
    my $dir = dirname( $out );
    $dir =~ s!/$!! unless $dir eq '/';
    unless ( $fmgr->exists( $dir ) ) {
        $fmgr->mkpath( $dir ) or return undef;
    }
    if (-f $directory ) {
        my $basename = File::Basename::basename( $directory );
        $archiver->addFile( $directory, $basename );
        return $archiver->writeToFileNamed( $out );
    }
    $directory =~ s!/$!!;
    unless ( $files ) {
        @$files = get_children_filenames( $directory );
    }
    $directory = quotemeta( $directory );
    for my $file ( @$files ) {
        my $new = $file;
        $new =~ s/^$directory//;
        $new =~ s!^/!!;
        $new =~ s!^\\!!;
        $archiver->addFile( $file, $new );
    }
    return $archiver->writeToFileNamed( $out );
}

sub get_children_filenames {
    my ( $directory, $pattern ) = @_;
    my @wantedFiles;
    require File::Find;
    if ( $pattern ) {
        if ( $pattern =~ m!^(/)(.+)\1([A-Za-z]+)?$! ) {
            $pattern = $2;
            if ( my $opt = $3 ) {
                $opt =~ s/[ge]+//g;
                $pattern = "(?$opt)" . $pattern;
            }
            my $regex = eval { qr/$pattern/ };
            if ( defined $regex ) {
                my $command = 'File::Find::find ( sub { push ( @wantedFiles, $File::Find::name ) if ( /' . $pattern. '/ ) && -f ; }, $directory );';
                eval $command;
                if ( $@ ) {
                    return undef;
                }
            } else {
                return undef;
            }
        }
    } else {
        File::Find::find ( sub { push ( @wantedFiles, $File::Find::name ) unless (/^\./) || ! -f ; }, $directory );
    }
    return @wantedFiles;
}

sub powercms_files_dir {
    my $powercms_files = powercms_files_dir_path();
    my $fmgr = MT::FileMgr->new( 'Local' ) or die MT::FileMgr->errstr;
    if (-d $powercms_files ) {
        if (-w $powercms_files ) {
            my $do = _create_powercms_subdir( $powercms_files );
            return chomp_dir( $powercms_files );
        }
        chmod ( 0777, $powercms_files );
        my $do = _create_powercms_subdir( $powercms_files );
        return chomp_dir( $powercms_files ) if (-w $powercms_files );
    }
    $powercms_files =~ s!/$!! unless $powercms_files eq '/';
    unless ( $fmgr->exists( $powercms_files ) ) {
        $fmgr->mkpath( $powercms_files );
        if (-d $powercms_files ) {
            unless (-w $powercms_files ) {
                chmod ( 0777, $powercms_files );
            }
        }
    }
    unless (-d $powercms_files ) {
        return undef;
    }
    if (-w $powercms_files ) {
        my $do = _create_powercms_subdir( $powercms_files );
        return chomp_dir( $powercms_files );
    }
    return undef;
}

sub powercms_files_dir_path {
    return MT->instance()->config( 'PowerCMSFilesDir' ) ||
        File::Spec->catdir( MT->instance()->mt_dir, 'powercms_files' );
}

sub _create_powercms_subdir {
    my $powercms_files = shift;
    if (-d $powercms_files ) {
        if (-w $powercms_files ) {
            my @dirs = qw( cache backup log mail lock report cmscache logrotate );
            for my $dir ( @dirs ) {
                my $directory = File::Spec->catdir( $powercms_files, $dir );
                unless (-e $directory ) {
                    if ( make_dir( $directory ) ) {
                        unless (-w $directory ) {
                            chmod ( 0777, $directory );
                        }
                    }
                } else {
                    unless (-w $directory ) {
                        chmod ( 0777, $directory );
                    }
                }
                return 0 unless (-w $directory );
            }
        }
    }
    return 1;
}

sub make_dir {
    my $path = shift;
    return 1 if (-d $path );
    my $fmgr = MT::FileMgr->new( 'Local' ) or return 0;# die MT::FileMgr->errstr;
    $path =~ s!/$!! unless $path eq '/';
    unless ( $fmgr->exists( $path ) ) {
        $fmgr->mkpath( $path );
        if (-d $path ) {
            # chmod ( 0777, $path );
            return 1;
        }
    }
    return 0;
}

sub chomp_dir {
    my $dir = shift;
    my @path = File::Spec->splitdir( $dir );
    $dir = File::Spec->catdir( @path );
    return $dir;
}

sub site_url {
    my $blog = shift;
    my $site_url = $blog->site_url;
    $site_url =~ s{/+$}{};
    return $site_url;
}

sub relative2path {
    my ( $path, $blog ) = @_;
    my $app = MT->instance();
    my $static_file_path = static_or_support();
    my $archive_path = archive_path( $blog );
    my $site_path = site_path( $blog );
    $path =~ s/%s/$static_file_path/;
    $path =~ s/%r/$site_path/;
    if ( $archive_path ) {
        $path =~ s/%a/$archive_path/;
    }
    return $path;
}

sub static_or_support {
    my $app = MT->instance();
    my $static_or_support;
    if ( MT->version_number < 5 ) {
        $static_or_support = $app->static_file_path;
    } else {
        $static_or_support = $app->support_directory_path;
    }
    return $static_or_support;
}

sub path2relative {
    my ( $path, $blog, $exclude_archive_path ) = @_;
    my $app = MT->instance();
    my $static_file_path = quotemeta( static_or_support() );
    my $archive_path = quotemeta( archive_path( $blog ) );
    my $site_path = quotemeta( site_path( $blog, $exclude_archive_path ) );
    $path =~ s/$static_file_path/%s/;
    $path =~ s/$site_path/%r/;
    if ( $archive_path ) {
        $path =~ s/$archive_path/%a/;
    }
    if ( $path =~ m!^https{0,1}://! ) {
        my $site_url = quotemeta( site_url( $blog ) );
        $path =~ s/$site_url/%r/;
    }
    return $path;
}

sub site_path {
    my ( $blog, $exclude_archive_path ) = @_;
    my $site_path;
    unless ( $exclude_archive_path ) {
        $site_path = $blog->archive_path;
    }
    $site_path = $blog->site_path unless $site_path;
    return chomp_dir( $site_path );
}

sub archive_path {
    my $blog = shift;
    my $archive_path = $blog->archive_path;
    return chomp_dir( $archive_path );
}

sub move_file {
    my ( $from, $to, $blog ) = @_;
    my $fmgr = MT::FileMgr->new( 'Local' ) or die MT::FileMgr->errstr;
    if ( $blog ) {
        $from = relative2path( $from, $blog );
        $to = relative2path( $to, $blog );
    }
    my $dir = dirname( $to );
    $dir =~ s!/$!! unless $dir eq '/';
    unless ( $fmgr->exists( $dir ) ) {
        $fmgr->mkpath( $dir ) or return MT->trans_error( "Error making path '[_1]': [_2]",
                                $to, $fmgr->errstr );
    }
    $fmgr->rename( $from, $to );
}

sub utf8_off {
    my $text = shift;
    return MT::I18N::utf8_off( $text );
}

sub log2text {
    my ( $msg, $out ) = @_;
    open  ( my $fh, ">> $out" ) || die "Can't open $out!";
    print $fh "$msg\n";
    close ( $fh );
}

sub current_ts {
    my $blog = shift;
    my @tl = offset_time_list( time, $blog );
    my $ts = sprintf '%04d%02d%02d%02d%02d%02d', $tl[5]+1900, $tl[4]+1, @tl[3,2,1,0];
    return $ts;
}

1;