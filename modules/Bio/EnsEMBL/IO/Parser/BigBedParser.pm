package Bio::EnsEMBL::IO::Parser::BigBedParser;
use strict;

use Bio::DB::BigBed;

sub open {
  my ($class, $url, @options) = @_;
  my %param_hash = @options;

  my $self = bless {
    _cache => {},
    _url => $url,
    iterator => undef,
    options => \%param_hash,
    current => undef,
  }, $class;

  $self->{_cache}->{_bigbed_handle} = $self->bigbed_open;
      
  return $self;
}

sub close {}

sub bigbed_open {
  my $self = shift;

  Bio::DB::BigFile->set_udc_defaults;
  $self->{_cache}->{_bigbed_handle} ||= Bio::DB::BigBed->new(-bigbed => $self->{_url});
  warn "Failed to open BigWig file " . $self->{_url} unless $self->{_cache}->{_bigbed_handle};
  $self->{chromList} = $self->{_cache}->{_bigbed_handle}->bf->chromList;
  $self->{nextChrom} = $self->{chromList}->head;
  return $self->{_cache}->{_bigbed_handle};
}

sub seek {
  my ($self, $chr_id, $start, $finish) = @_;
  $self->{nextChrom} = undef;

  #  Maybe need to add 'chr' 
  my $seq_id = $self->munge_chr_id($chr_id);
  if (defined $seq_id) {
     $self->{iterator} = $self->{_cache}->{_bigbed_handle}->get_seq_stream(-seq_id => $seq_id, -start => $start, -end => $finish);
  } else {
     $self->{iterator} = undef;
  }
}

sub next {
  my $self = shift;
  if (defined $self->{iterator}) {
    $self->{current} = $self->{iterator}->next_seq;
    if (defined $self->{current}) {
      return 1;
    } 
  }
  
  if (defined $self->{nextChrom}) {
    # If chromosomes left to visit, load next chromosome 
    my $next_chrom = $self->{nextChrom}->name;
    my $next_length = $self->{nextChrom}->size;
    $self->{nextChrom} = $self->{nextChrom}->next;
    $self->{iterator} = $self->{_cache}->{_bigbed_handle}->get_seq_stream(-seq_id => $next_chrom, -start => 0, -end => $next_length);
    return $self->next;
  } else {
    return 0;
  }
}

sub getRawChrom {
  my $self = shift;
  return $self->{current}->seq_id;
}

sub getChrom {
  my $self = shift;
  return $self->getRawChrom;
}

sub getRawStart {
  my $self = shift;
  return $self->{current}->start;
}

sub getStart {
  my $self = shift;
  return $self->getRawStart;
}

sub getRawEnd {
  my $self = shift;
  return $self->{current}->end;
}

sub getEnd {
  my $self = shift;
  return $self->getRawEnd;
}

sub getRawScore {
  my $self = shift;
  return $self->{current}->score;
}

sub getScore {
  my $self = shift;
  return $self->getRawScore;
}

sub getRawStrand {
  my $self = shift;
  return $self->{current}->strand;
}

sub getStrand {
  my $self = shift;
  return $self->getRawStrand;
}

sub getRawParts {
  my $self = shift;
  return $self->{current}->get_SeqFeatures;
}

sub getParts {
  my $self = shift;
  return $self->getRawParts;
}

sub getRawName {
  my $self = shift;
  return $self->{current}->name;
}

sub getName {
  my $self = shift;
  return $self->getRawName;
}

sub getRawRGB {
  my $self = shift;
  return $self->{current}->attributes('RGB');
}

sub getRGB {
  my $self = shift;
  return $self->getRawRGB;
}

sub getBEDFeature {
  my $self = shift;
  return $self->{current};
}

# UCSC prepend 'chr' on human chr ids. These are in some of the BigBed
# files. This method returns a possibly modified chr_id after
# checking whats in the BigBed file
sub munge_chr_id {
  my ($self, $chr_id) = @_;

  # Check we get values back for seq region. Maybe need to add 'chr' 
  if ($self->{_cache}->{_bigbed_handle}->chromSize($chr_id)) {
      return $chr_id;
  } elsif ($self->{_cache}->{_bigbed_handle}->chromSize("chr$chr_id")) {
      return "chr$chr_id";
  } else {
      warn " *** could not find region $chr_id in BigWig file\n";
      return undef;
  }
}

sub fetch_extended_summary_array {
  my ($self, $chr_id, $start, $end, $bins) = @_;

  #  Maybe need to add 'chr' 
  my $seq_id = $self->munge_chr_id($chr_id);

  if (defined $seq_id ) {
    # Remember this method takes half-open coords (subtract 1 from start)
    return $self->{_cache}->{_bigbed_handle}->bigBedSummaryArrayExtended($seq_id,$start-1,$end,$bins);
  } else {
    return [];
  }
}

sub fetch_features  {
  my ($self, $chr_id, $start, $end) = @_;
  $self->seek($chr_id, $start, $end);

  my @features;
  while ($self->next) {
    push @features,$self->getBEDFeature;
  }
  return \@features;
}

sub file_bedline_length {
  my $self = shift;
  my $length = 3;

  # If already fetched some features using this adaptor then use cached max number of fields
  if (exists($self->{_cache}->{numfield})) {
    return $self->{_cache}->{numfield};
  }

  # Else sample the file - this is rather inefficient
  my $num = 100;

  # list needs to exist and not be undefed until done to avoid SIGSEG
  for (my $c = $self->{_cache}->{_bigbed_handle}->chromList->head; $c && $num; $c=$c->next) {
    my $intervals = $self->{_cache}->{_bigbed_handle}->bigBedIntervalQuery($c->name,0,$c->size,$num);
    for (my $i=$intervals->head;$i && $num;$i=$i->next) {
      $length = max($length,3 + scalar split(/\t/,$i->rest));
      $num--;
    }
  }
  return $length;
}

1;
