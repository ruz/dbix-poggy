use strict; use warnings;

use Test::More !$ENV{POGGY_TEST_DSN}? (skip_all => 'no POGGY_TEST_DSN set') : ();
use_ok('AnyEvent');
use Promises qw(collect deferred);

use_ok 'DBIx::Poggy';
my $pool = DBIx::Poggy->new( pool_size => 3 );
$pool->connect($ENV{POGGY_TEST_DSN}, 'postgres');

note "server closed connection";
{
    my $cv = AnyEvent->condvar;
    $cv->begin;
    $cv->begin;
    {
        my $dbh1 = $pool->take;
        $dbh1->do(
            'select pg_sleep(10)'
        )->then( sub {
            fail "success is not expected";
        })
        ->catch(sub{
            pass "error is expected"
        })
        ->finally(sub{ $cv->end });

        $pool->take->do(
            'select pg_terminate_backend(?)', undef, $dbh1->{pg_pid},
        )
        ->then( sub {
            pass "terminated";
        })
        ->catch(sub{
            fail "error is not expected" or "error: ". $_[0]->{errstr};
        })
        ->finally(sub{ $cv->end });
    }

    $cv->recv;

    is scalar @{ $pool->{free} }, 2;
}

done_testing;
