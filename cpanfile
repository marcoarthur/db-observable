requires 'Mojo::Base';
requires 'RxPerl::Mojo';
requires 'DBI';
requires 'Try::Tiny';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

