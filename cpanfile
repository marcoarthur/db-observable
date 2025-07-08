requires 'Mojo::Base';
requires 'RxPerl::Mojo';
requires 'DBI';
requires 'Try::Tiny';

on test => sub {
    requires 'Test::More';
    requires 'Test::Mojo';
    requires 'DBD::SQLite';
    requires 'Test::Exception';
};
