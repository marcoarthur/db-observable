use strict;
use warnings;
use Test::More;
use Test::Exception;
use DB::Observable;
use feature qw(signatures);
use DDP;

# Skip all tests if dependencies are missing
eval {
    require DBD::SQLite;
    require RxPerl::Mojo;
};
plan skip_all => 'DBD::SQLite or RxPerl::Mojo not installed' if $@;

# Initialize test database in memory
my $db = DB::Observable->new({ dsn => 'dbi:SQLite:dbname=:memory:' });

#Create a test table and insert some data
sub init_test_db {
    my $dbh = shift;
    $dbh->do('CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT, value INTEGER)');
    $dbh->do('INSERT INTO test (name, value) VALUES (?, ?)', undef, 'foo', 10);
    $dbh->do('INSERT INTO test (name, value) VALUES (?, ?)', undef, 'bar', 20);
    $dbh->do('INSERT INTO test (name, value) VALUES (?, ?)', undef, 'baz', 30);
}

# Test connect method
subtest 'connect' => sub {
    my $connected;
    $db->connect->subscribe(
        {
            next => sub {
                my $dbh = shift;
                $connected = 1;
                isa_ok($dbh, 'DBI::db', 'Returns a DBI handle');
                init_test_db($dbh);
                $db->disconnect($dbh)->subscribe();
            },
            error => sub { fail("Connection failed: $_[0]") },
        }
    );
    
    ok($connected, 'Successfully connected to SQLite in-memory DB');
};

# Test query method
subtest 'query' => sub {
    my $dbh = DBI->connect('dbi:SQLite:dbname=:memory:');
    init_test_db($dbh);
    
    my @results;
    $db->query($dbh, 'SELECT * FROM test WHERE value > ?', 15)->subscribe(
        {
            next => sub ($row){push @results, $row},
            complete => sub {
                is(scalar @results, 2, 'Got 2 rows matching condition');
                is($results[0]{name}, 'bar', 'First row name matches');
                is($results[1]{name}, 'baz', 'Second row name matches');
                $db->disconnect($dbh)->subscribe();
            },
            error => sub { fail("Query failed: $_[0]") },
        }
    );
};


# Test run_query method
subtest 'run_query' => sub {
    $db->once( connected => sub ($self, $dbh) { init_test_db($dbh) } );
    $db->on( connected => sub ($db, $dbh){ ok $dbh, 'nicely connect before query' } );
    $db->on( disconnected => sub ($db, $dsn){ ok $dsn = $db->dsn, 'nicely disconnect after query' } );
    my @results;
    $db->run_query(
        {
            query => 'SELECT * FROM test WHERE name LIKE ?',
            binds => ['ba%']
        }
    )->subscribe( { next => sub ($row) { push @results, $row } });
    
   is(scalar @results, 2, 'run_query returned 2 rows');
   is($results[0]{name}, 'bar', 'First row name matches');
   is($results[1]{name}, 'baz', 'Second row name matches');
};

# Test error handling
subtest 'error handling' => sub {
    my $error;
    $db->query(undef, 'INVALID SQL')->subscribe(
        {
            next => sub { fail("Should not get results for invalid query") },
            error => sub ($err){ $error = $err },
        }
    );
    
    like($error, qr/Query failed:/, 'Got error for invalid query');
};

done_testing();
