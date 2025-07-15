package DB::Observable;
use Mojo::Base 'Mojo::EventEmitter', -signatures;
use RxPerl::Mojo qw(:all);
use DBI;
use Try::Tiny;

our $VERSION = "0.01";

has [qw(dsn username password)];

sub connect ($self) {
  return rx_observable->new(
    sub ($observer) {
      try {
        my $dbh = DBI->connect(
          $self->dsn,
          $self->username,
          $self->password,
          { RaiseError => 0, AutoCommit => 1 }
        );

        if ($dbh) {
          $self->emit( connected => $dbh );
          $observer->next($dbh);
          $observer->complete;
        } else {
          $self->emit( error => $DBI::errstr );
          $observer->error("Connection failed: $DBI::errstr");
        }
      } catch {
        $observer->error("Connection error: $_");
      };
    });
}

sub query ($self, $dbh, $sql, @bind_values) {
  return rx_observable->new(
    sub($observer) {
      try {
        my $sth = $dbh->prepare($sql);
        $sth->execute(@bind_values);

        while (my $row = $sth->fetchrow_hashref) {
          $self->emit(data => $row);
          $observer->next($row);
        }

        $observer->complete;
      } catch {
        $observer->error("Query failed: $_");
      };
    });
}

sub disconnect ($self, $dbh) {
  return rx_observable->new(
    sub ($observer){
      try {
        $dbh->disconnect;
        $self->emit( disconnected => $self->dsn );
        $observer->next("Disconnected");
        $observer->complete;
      } catch {
        $self->emit( error => $_ );
        $observer->error("Disconnect failed: $_");
      };
    });
}

sub run_query($self, $q, $cb = sub { $_ }) {
  $self->connect->pipe(
    op_merge_map(
      sub ($dbh, $idx) {
        my $query_obs = $self->query($dbh, $q->{query}, @{$q->{binds}});

        return $query_obs->pipe(
          op_map($cb),
          op_finalize(
            sub {
              $self->disconnect($dbh)->subscribe(
                { 
                  next      => sub {},
                  error     => sub ($err){ warn "Disconnect Error: $err" },
                  complete  => sub { Mojo::IOLoop->stop },
                }
              );
            }),
        );
      })
  );
}

1;

=pod

=head1 STATUS

[![Coverage Status](https://coveralls.io/repos/github/marcoarthur/db-observable/badge.svg?branch=main)](https://coveralls.io/github/marcoarthur/db-observable?branch=main)

=head1 NAME

DB::Observable - A reactive database module using Mojo::EventEmitter and RxPerl

=head1 SYNOPSIS

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

=head1 DESCRIPTION

DB::Observable provides a reactive interface for database operations using RxPerl
observables. It extends Mojo::EventEmitter to provide event-based database access
with asynchronous capabilities.

The module supports connection management, query execution, and disconnection,
all through observable sequences that can be composed and transformed.

=head1 ATTRIBUTES

=head2 dsn

Database DSN string (e.g., 'dbi:mysql:database=test').

=head2 username

Database username.

=head2 password

Database password.

=head1 METHODS

=head2 new

  my $db = DB::Observable->new(\%args);

Creates a new DB::Observable instance. Accepts:
- dsn (required)
- username (optional)
- password (optional)

=head2 connect

  my $observable = $db->connect;

Returns an observable that will emit a database handle on successful connection
or an error if connection fails.

=head2 query

  my $observable = $db->query($dbh, $sql, @bind_values);

Returns an observable that emits each row of the result set as it's fetched.
Takes:
- $dbh: Database handle from connect()
- $sql: SQL query string
- @bind_values: Optional bind values for the query

=head2 disconnect

  my $observable = $db->disconnect($dbh);

Returns an observable that emits a "Disconnected" message on success or an error
if disconnection fails.

=head2 run_query

  $db->run_query(\%query, $callback);

Convenience method that handles the full lifecycle:
1. Connects to database
2. Executes query
3. Processes each row through callback
4. Disconnects

Parameters:
- \%query: Hash with 'query' (SQL string) and 'binds' (arrayref of bind values)
- $callback: Subroutine to process each row (optional, defaults to identity function)

=head1 EXAMPLES

=head2 Basic Query

  $db->run_query({
    query => 'SELECT * FROM products WHERE price > ?',
    binds => [100]
  }, sub {
    my $product = shift;
    say "Expensive product: $product->{name}";
  });

=head2 Error Handling

  $db->connect->subscribe(
    next => sub { ... },
    error => sub {
      warn "Database connection failed: $_[0]";
    }
  );

=head1 SEE ALSO

=over

=item * L<RxPerl> - Reactive Extensions for Perl

=item * L<Mojo::EventEmitter> - Event emitter base class

=item * L<DBI> - Perl Database Interface

=back

=head1 AUTHOR

Marco Arthur <arthurpbs@gmail.com>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
