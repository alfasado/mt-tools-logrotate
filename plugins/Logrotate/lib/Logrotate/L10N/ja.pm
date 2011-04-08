package Logrotate::L10N::ja;
use strict;
use base 'Logrotate::L10N';
use vars qw( %Lexicon );
our %Lexicon = (
    'Logrotate MT\'s System Log.' => 'MTのシステムログをローテーションします。',
    'Compress' => '圧縮',
    'Logfile compress to zip' => 'ログファイルをZIP圧縮する',
    'Log to csv older than(day(s))' => '日数経過したログを保存',
    'Log age' => '世代分のログを保存する',
);
1;