
# NAME

DB::Observable - A reactive database module using Mojo::EventEmitter and RxPerl

# SYNOPSIS

    use DB::Observable;

    my $db = DB::Observable->new({
      dsn      => 'dbi:mysql:database=test',
      username => 'user',
      password => 'pass'
    });

    # Run a simple query
    $db->run_query({
      query => 'SELECT * FROM users WHERE id > ?',
      binds => [1]
    }, sub {
      my $row = shift;
      say "Got user: $row->{name}";
    });

    # Manual connection and query
    $db->connect->subscribe(
    {
      next => sub {
        my $dbh = shift;
        $db->query($dbh, 'SELECT * FROM products')->subscribe(
        {
          next     => sub ($row){ say "Product: $row->{name}" },
          error    => sub ($err){ warn "Query error: $err" },
          complete => sub { $db->disconnect($dbh) }
        }
      )},
      error => sub { warn "Connection failed: $_[0]" }
    });

# DESCRIPTION

DB::Observable provides a reactive interface for database operations using RxPerl
observables. It extends Mojo::EventEmitter to provide event-based database access
with asynchronous capabilities.

The module supports connection management, query execution, and disconnection,
all through observable sequences that can be composed and transformed.

# ATTRIBUTES

## dsn

Database DSN string (e.g., 'dbi:mysql:database=test').

## username

Database username.

## password

Database password.

# METHODS

## new

    my $db = DB::Observable->new(\%args);

Creates a new DB::Observable instance. Accepts:
\- dsn (required)
\- username (optional)
\- password (optional)

## connect

    my $observable = $db->connect;

Returns an observable that will emit a database handle on successful connection
or an error if connection fails.

## query

    my $observable = $db->query($dbh, $sql, @bind_values);

Returns an observable that emits each row of the result set as it's fetched.
Takes:
\- $dbh: Database handle from connect()
\- $sql: SQL query string
\- @bind\_values: Optional bind values for the query

## disconnect

    my $observable = $db->disconnect($dbh);

Returns an observable that emits a "Disconnected" message on success or an error
if disconnection fails.

## run\_query

    $db->run_query(\%query, $callback);

Convenience method that handles the full lifecycle:
1\. Connects to database
2\. Executes query
3\. Processes each row through callback
4\. Disconnects

Parameters:
\- \\%query: Hash with 'query' (SQL string) and 'binds' (arrayref of bind values)
\- $callback: Subroutine to process each row (optional, defaults to identity function)

# EXAMPLES

## Basic Query

    $db->run_query({
      query => 'SELECT * FROM products WHERE price > ?',
      binds => [100]
    }, sub {
      my $product = shift;
      say "Expensive product: $product->{name}";
    });

## Error Handling

    $db->connect->subscribe(
      next => sub { ... },
      error => sub {
        warn "Database connection failed: $_[0]";
      }
    );

# SEE ALSO

- [RxPerl](https://metacpan.org/pod/RxPerl) - Reactive Extensions for Perl
- [Mojo::EventEmitter](https://metacpan.org/pod/Mojo%3A%3AEventEmitter) - Event emitter base class
- [DBI](https://metacpan.org/pod/DBI) - Perl Database Interface

# AUTHOR

Marco Arthur <arthurpbs@gmail.com>

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
