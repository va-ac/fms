package FixMyStreet::SendReport::Zurich;

use Moo;

BEGIN { extends 'FixMyStreet::SendReport::Email'; }

sub build_recipient_list {
    my ( $self, $row, $h ) = @_;

    # Only one body ever, most of the time with an email endpoint
    my $body = @{ $self->bodies }[0];

    # we set external_message (but default to '' in case of race condition e.g.
    # Wunsch set, but external_message hasn't yet been filled in.  TODO should
    # we instead be holding off sending?)
    if ( $row->external_body ) {
        $body = $row->result_source->schema->resultset("Body")->find( { id => $row->external_body } );
        $h->{bodies_name} = $body->name;
        $h->{external_message} = $row->get_extra_metadata('external_message') || '';
    }
    $h->{external_message} //= '';

    my ($west, $nord) = $row->local_coords;
    $h->{west} = $west;
    $h->{nord} = $nord;

    my $body_email = $body->endpoint;

    my $parent = $body->parent;
    if ($parent && !$parent->parent) {
        # Division, might have an individual contact email address
        my $contact = $row->result_source->schema->resultset("Contact")->find( {
            body_id => $body->id,
            category => $row->category
        } );
        $body_email = $contact->email if $contact && $contact->email;
    }

    push @{ $self->to }, [ $body_email, $body->name ];
    return 1;
}

sub get_template {
    my ( $self, $row ) = @_;

    my $template;
    if ( $row->state eq 'unconfirmed' || $row->state eq 'confirmed' ) {
        $template = 'submit.txt';
    } elsif ( $row->state eq 'in progress' ) {
        $template = 'submit-in-progress.txt';
    } elsif ( $row->state eq 'planned' ) {
        $template = 'submit-feedback-pending.txt';
    } elsif ( $row->state eq 'investigating' ) {
        $template = 'submit-external-wish.txt';
    } elsif ( $row->state eq 'closed' ) {
        $template = 'submit-external.txt';
        if ( $row->extra->{third_personal} ) {
            $template = 'submit-external-personal.txt';
        }
    }

    return $template;
}

# Zurich emails come from the site itself, unless it's to an external body,
# in which case it's from the category/body
sub send_from {
    my ( $self, $row ) = @_;

    if ( $row->external_body ) {
        my $body = @{ $self->bodies }[0];
        my $body_email = $body->endpoint;
        my $contact = $body->result_source->schema->resultset("Contact")->find( {
            body_id => $body->id,
            category => $row->category
        } );
        $body_email = $contact->email if $contact && $contact->email;
        return [ $body_email, FixMyStreet->config('CONTACT_NAME') ];
    }

    return [ FixMyStreet->config('CONTACT_EMAIL'), FixMyStreet->config('CONTACT_NAME') ];
}

1;
