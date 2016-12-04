use strict;
use warnings;
use Test::More;
use utf8;

use FixMyStreet::TestMech;
use FixMyStreet::App;

my $mech = FixMyStreet::TestMech->new;
my $user = $mech->create_user_ok('bob@example.com', name => 'Bob');

subtest 'Zurich special case for C::Tokens->problem_confirm' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => ['zurich'],
    }, sub {
        my $c = FixMyStreet::App->new;
        my $zurich = $mech->create_body_ok( 1, 'Zurich' );
        my ($report) = $mech->create_problems_for_body( 
            1, $zurich->id,
            {
                state     => 'unconfirmed',
                confirmed => undef,
                cobrand   => 'zurich',
            });
        
        is $report->get_extra_metadata('email_confirmed'), undef, 'email_confirmed not yet set (sanity)';
        my $token = $c->model('DB::Token')->create({ scope => 'problem', data => $report->id });

        $mech->get_ok('/P/' . $token->token);
        $report->discard_changes;
        is $report->get_extra_metadata('email_confirmed'), 1, 'email_confirmed set by Zurich special case'; 
    };
};

done_testing;
