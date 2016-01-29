package AutoHarp::Composer::PerformanceSegment;

use strict;
use base qw(AutoHarp::Composer::CompositionElement);
use Carp;

use AutoHarp::MusicBox::Base;
use AutoHarp::Constants;
use AutoHarp::Notation;

my $PLAYER        = 'player';
my $PERFORMANCES  = 'performances';
my $PLAYED        = 'played';
my $HALF          = 'half';
my $FIRST_HALF    = 'firstHalf';
my $SECOND_HALF   = 'secondHalf';

sub fromParent {
  my $class = shift;
  my $parent = shift;
  return bless $parent->clone(), $class;
}

sub toDataStructure {
  my $self = shift;
  if ($self->hasPerformances() && !$self->hasMusic()) {
    confess "Attempted to serialize music segment with performances but no music!";
  } 
  my $ds = {$AH_CLASS => ref($self),
	    $ATTR_UID => $self->uid(),
	    $SONG_ELEMENT_TRANSITION => $self->transitionOut(),
	   };
  if ($self->hasMusic()) {
    $ds->{$ATTR_MUSIC} = $self->musicBox->uid;
  }
  if ($self->hasPerformances()) {
    my $guide = $self->musicBox->guide();
    $ds->{$PERFORMANCES} = 
      {
       map {$_ => $self->{$PERFORMANCES}{$_}{$PLAYED}->toDataStructure($guide)}
       keys %{$self->{$PERFORMANCES}}
      };
  }
  if ($self->isFirstHalf()) {
    $ds->{$HALF} = $FIRST_HALF;
  } elsif ($self->isSecondHalf()) {
    $ds->{$HALF} = $SECOND_HALF;
  }

  return $ds;
}

sub fromDataStructure {
  my $class   = shift;
  my $ds      = shift;
  my $session = shift;
  confess "THIS DOESN'T WORK";

  if (!$session || 
      !$session->hasSeedMusic() ||
      !$session->hasInstruments()
     ) {
    confess "Session containing music and instruments must be passed to reconstruct a song segment"
  }
  my $self = {};
  my $guide;
  if ($ds->{$ATTR_MUSIC}) {
    my $musicMap = {map {$_->uid => $_} @{$session->seedMusic()}};
    my $music    = $musicMap->{$ds->{$ATTR_MUSIC}};
    if (!$music) {
      confess "Couldn't find music $ds->{$ATTR_MUSIC} in session";
    }
    if ($ds->{$HALF} eq $FIRST_HALF) {
      $self->{$ATTR_MUSIC} = $music->clone()->halve();
      $self->{$FIRST_HALF} = 1;
    } elsif ($ds->{$HALF} eq $SECOND_HALF) {
      $self->{$ATTR_MUSIC} = $music->secondHalf();
      $self->{$SECOND_HALF} = 1;
    } else {
      $self->{$ATTR_MUSIC} = $music->clone();
    }
    $guide = $self->{$ATTR_MUSIC}->guide();
  } 
  if ($ds->{$PERFORMANCES}) {
    if (!$guide) {
      confess "Attempted to unserialize music with performances but no music";
    }
    while (my ($inst_id, $perf) = each %{$ds->{$PERFORMANCES}}) {
      my $inst = $session->instrument($inst_id);
      my $perf = AutoHarp::Class->fromDataStructure($perf);
      if (!$inst) {
	confess "Segment contained an instrument not found in the session";
      }
      $self->{$PERFORMANCES}{$inst_id} = {$PLAYER => $inst,
					  $PLAYED => $perf};
    }
  }
  bless $self,$class;
  $self->transitionOut($ds->{$SONG_ELEMENT_TRANSITION});
  return $self;
}

sub isIntro {
  return (shift)->songElement =~ /$SONG_ELEMENT_INTRO/i;
}

sub isVerse {
  return (shift)->songElement =~ /$SONG_ELEMENT_VERSE/i;
}

sub isChorus {
  return (shift)->songElement =~ /$SONG_ELEMENT_CHORUS/i;
}

sub nextSongElement {
  return $_[0]->scalarAccessor('nextElt',$_[1]);
}

#for noting that we "came down" 
#(brought the song down a notch, as it were)
#at the start of this segment
sub wasComeDown {
  return $_[0]->transitionIn() eq $ATTR_DOWN_TRANSITION;
}

#for noting the opposite
sub wasBuildUp {
  return $_[0]->transitionIn() eq $ATTR_UP_TRANSITION;
}

sub transitionOutIsDown {
  return $_[0]->transitionOut() eq $ATTR_DOWN_TRANSITION;
}

sub transitionOutIsUp {
  return $_[0]->transitionOut() eq $ATTR_UP_TRANSITION;
}

#for noting if this segment is part of a repeat  
sub isRepeat {
  my $self = shift;
  return $self->scalarAccessor('isRepeat',@_);
}

#inferred by the fact that the next segment matches this segment
#and we are a second half.
sub nextHalfSegmentIsRepeat {
  my $self = shift;
  return ($self->songElement eq $self->nextSongElement() && 
	  $self->isSecondHalf());
}

#we're the start of a new thing (e.g. a chorus after a verse
sub isChange {
  my $self = shift;
  return (!$self->isRepeat() && $self->isFirstHalf());
}

#for noting what number verse/chorus this is
sub elementIndex {
  my $self = shift;
  return $self->scalarAccessor('elementIndex',@_);
}

#if we split a composition element into pieces, what idx is this one?
sub segmentIndex {
  my $self = shift;
  return $self->scalarAccessor('segmentIdx',@_);
}

#legacy--for noting if this segment is half of a chorus/verse/whatever
sub isFirstHalf {
  return ($_[0]->segmentIndex() == 0);
}

#legacy, see above
sub isSecondHalf {
  return ($_[0]->segmentIndex > 0);
}

sub transitionOut {
  return $_[0]->scalarAccessor('transitionOut',$_[1],$ATTR_STRAIGHT_TRANSITION);
}

sub transitionIn {
  return $_[0]->scalarAccessor('transitionIn',$_[1],$ATTR_STRAIGHT_TRANSITION);
}

sub soundingTime {
  my $self = shift;
  if ($self->hasPerformances()) {
    my $st;
    foreach my $s (@{$self->scores()}) {
      if (!length($st) || $s->soundingTime < $st) {
	$st = $s->soundingTime();
      }
    }
    return $st;
  } elsif ($self->hasMusic()) {
    return $self->musicBox()->soundingTime();
  }
  return $self->time;
}

sub scores {
  my $self = shift;
  return [
	  grep {ref($_)} 
	  map {$self->{$PERFORMANCES}{$_}{$PLAYED}} 
	  keys %{$self->{$PERFORMANCES}}
	 ];
}

sub playerPerformances {
  my $self = shift;
  return [map 
	  {
	    {$ATTR_INSTRUMENT => $self->{$PERFORMANCES}{$_}{$PLAYER},
	       $ATTR_MELODY => $self->{$PERFORMANCES}{$_}{$PLAYED}
	     }
	  } 
	  grep {$self->{$PERFORMANCES}{$_}{$PLAYED}}
	  keys %{$self->{$PERFORMANCES}}
	 ];
}

sub player {
  my $self = shift;
  my $id = shift;
  return (exists $self->{$PERFORMANCES}{$id}) ?
    $self->{$PERFORMANCES}{$id}{$PLAYER} : undef
}

sub hasPlayers {
  return scalar keys %{$_[0]->{$PERFORMANCES}};
}

sub players {
  my $self = shift;
  return [keys %{$self->{$PERFORMANCES}}];
}

#note that we expect a performance from a particular instrument
sub addPerformerId {
  my $self = shift;
  my $id   = shift;
  $self->{$PERFORMANCES}{$id} ||= {};
}

sub hasPerformances {
  my $self = shift;
  if ($self->{$PERFORMANCES} && scalar keys %{$self->{$PERFORMANCES}}) {
    foreach my $id (keys %{$self->{$PERFORMANCES}}) {
      return 1 if ($self->{$PERFORMANCES}{$id}{$PLAYED});
    }
  }
  return;
}

sub addPerformance {
  my $self   = shift;
  my $player = shift;
  my $play   = shift;

  if (!$play->duration) {
    confess "Attempted to add 0-duration performance";
  }

  my $storedPlay = $play->clone();
  $storedPlay->time($self->time);
  $self->{$PERFORMANCES}{$player->uid} = {$PLAYER => $player,
					  $PLAYED => $storedPlay};
}
      
"Just hear me out--I'm not over you yet";
