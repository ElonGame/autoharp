package AutoHarp::Instrument::Hook;

use strict;
use AutoHarp::Constants;
use AutoHarp::Fuzzy;
use Carp;
use base qw(AutoHarp::Instrument);

sub choosePatch {
  my $self = shift;
  my $inst = shift;

  if (!$inst && almostAlways) {
    $inst = pickOne('Electric Guitar(muted)',
		    'chromatic percussion',
		    'ensemble',
		    'pipe');
  } 
  return $self->SUPER::choosePatch($inst);
}

sub playDecision {
  my $self     = shift;
  my $segment  = shift;

  my $was      = $self->isPlaying();
  
  if ($segment->songElement eq $SONG_ELEMENT_INTRO) {
    return ($segment->isSongBeginning) ? rarely : mostOfTheTime;
  } elsif ($segment->songElement eq $SONG_ELEMENT_CHORUS) {
    return ($segment->isRepeat()) ? asOftenAsNot : 0;
  } elsif ($segment->songElement eq $SONG_ELEMENT_BRIDGE) {
    return;
  } elsif ($segment->songElement eq $SONG_ELEMENT_OUTRO ||
	   $segment->songElement eq $SONG_ELEMENT_INSTRUMENTAL) {
    return unlessPigsFly;
  } elsif ($segment->isChange() && $was) {
    #if this is a change and we were, stop
    return;
  } elsif ($segment->wasComeDown() && !$was) {
    #if we came down and we weren't, why not start?
    return often;
  }

  return $was;
}

sub play {
  my $self = shift;
  my $segment = shift;
  if ($segment->hasHook()) {
    return $segment->hook->adaptOnto($segment->musicBox())->melody();
  }
  #there no be hook here, so I don't play
  return;
}

"Now and then I think of when we were together";
