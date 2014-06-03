=pod

=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

  http://www.ensembl.org/info/about/code_licence.html

=head1 NAME

Bio::EnsEMBL::IO::Parser::TokenBasedParser - An abstract parser class 
specialised for files with keyed fields or data that comprise a multi-
lined record.

An extension of the TextParser class that provides is_at_end_of_record and is_at_beginning of record functions:

If you are extending this class you need to implement:
- is_metadata: determines whether $self->{current_block} is metadata
- read_metadata: reads $self->{current_block}, stores relevant data in $self->{metadata} hash ref
- read_record: reads $self->{current_block}, possibly invoking $self->next_block(), stores list in $self->{record}
- a bunch of getters.
- validate_record: reads $self->{record}, checks content
- validate_metadata: reads $self->{current_block}, checks metadata 

Optionally, you may want to implement:
- seek: seeks coordinate in sorted/indexed file

=cut

package Bio::EnsEMBL::IO::TokenBasedParser;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Utils::Scalar qw/assert_ref/;

use base qw/Bio::EnsEMBL::IO::TextParser/;

sub open {
    my ($caller, $filename, $start_tag, $end_tag, @other_args) = @_;

    if (! defined $start_tag && ! defined $end_tag) {
        throw("C'mon, gimme something to work with, you cannot define a TokenBasedParser without tokens!");
    }

    my $class = ref($caller) || $caller;
    
    my $self = $class->SUPER::open($filename, @other_args);
    $self->{'start_tag'} = $start_tag;
    $self->{'end_tag'} = $end_tag;
    
    return $self;
}

=head2 is_at_end_of_record

    Description : Determines whether the next line belongs in record
    Returntype  : Boolean

=cut

sub is_at_end_of_record {
    my $self = shift;
    return (defined $self->{'end_tag'} && $self->{'current_block'} =~ /$self->{'end_tag'}/) 
           || !defined $self->{'waiting_block'}
           || (defined $self->{'start_tag'} && $self->{'waiting_block'} =~ /$self->{'start_tag'}/);
}

=head2 is_end_of_record

    Description : Determines whether the current line is the first line of a record
    Returntype  : Boolean

=cut

sub is_at_beginning_of_record {
    my $self = shift;
    return !defined $self->{'start_tag'} || $self->{'current_block'} =~ /$self->{'start_tag'}/
           || !defined $self->{'waiting_block'};
}

1;
