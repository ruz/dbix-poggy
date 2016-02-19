use strict; use warnings;

use Test::More !$ENV{POGGY_TEST_DSN}? (skip_all => 'no POGGY_TEST_DSN set') : ();
use_ok('AnyEvent');
use Promises qw(collect);

use_ok 'DBIx::Poggy';
my $pool = DBIx::Poggy->new( pool_size => 3 );
$pool->connect($ENV{POGGY_TEST_DSN}, 'postgres');

{
    my $cv = AnyEvent->condvar;
    $pool->take->do(
        'CREATE TABLE IF NOT EXISTS poggy_users (email varchar(255) primary key, password varchar(64))'
    )->done(
        sub { ok $_[0], "created table"; $cv->send },
        sub { fail "error is not expected, but we got: ". $_[0]->{errstr}; $cv->send }
    );
    is scalar @{ $pool->{free} }, 2;
    $cv->recv;
    is scalar @{ $pool->{free} }, 3;
}

{
    my $cv = AnyEvent->condvar;

    my $dbh = $pool->take;
    is scalar @{ $pool->{free} }, 2;
    $dbh->begin_work->finally($cv);

    $dbh->do(
        'DELETE FROM poggy_users'
    )
    ->then(sub {
        is scalar @{ $pool->{free} }, 2;
        return $dbh->do('INSERT INTO poggy_users (email) VALUES (?)', undef, 'u@example.com');
    })
    ->then(sub {
        is scalar @{ $pool->{free} }, 2;
        return $dbh->commit;
    })
    ->catch(sub {
        fail "error is not expected";
        $dbh->rollback;
    });
    is scalar @{ $pool->{free} }, 2;
    $cv->recv;
    is scalar @{ $pool->{free} }, 3;
}

done_testing;
