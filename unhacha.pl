#!/usr/bin/perl
##############################################################################
#
# $Id: unhacha.pl,v 1.1 2002/09/24 16:07:24 xabi <mail@xa.bi> Exp $

sub getHeader {
  my $sFile = $_[0];
  return { 'ok' => 0, 'msg' => "Error [$sFile] does not exist."} unless (-f $sFile);
  open(IN, $sFile) || return { 'ok' => 0, 'msg' => "Could not open file [$sFile]."};
  binmode(IN);               # now DOS won't mangle binary input from GIF
  my $sHeader = "";
  my $sFullHeader = "";
  my $sBuff;
  while (read(IN, $sBuff, 10)) {
    $sHeader .= $sBuff;
    last if (($sFullHeader) = ($sHeader =~ /(\?\?\?\?\?.*\?\?\?\?\?.*\?\?\?\?\?.*\?\?\?\?\?.*\?\?\?\?\?)/));
  }
  close(IN);
  if ($sHeader =~ /\?\?\?\?\?.*\?\?\?\?\?(.*)\?\?\?\?\?(.*)\?\?\?\?\?(.*)\?\?\?\?\?/) {
    return { 'ok' => 1, 'name' => $1, 'header' => length($sFullHeader), 'total' => $2, 'block' => $3 };
  } else {
    return { 'ok' => 0, 'msg' => "Error [$sFile] is not a Hacha file." };
  }
}

sub writeToFile {
  my ($sOut, $sIn, $iInit) = @_;
  if (-f $sIn) {
    open(IN, $sIn);
    open(OUT, ">>" . $sOut);
    binmode(IN);
    binmode(OUT);
    seek(IN, $iInit, 0);
    while (read(IN, $sBuff, 100 * 1024)) {
      print OUT  $sBuff;
    }
    close(OUT);
    close(IN);
    return ((stat($sIn))[7] - $iInit);
  } else {
    return -1
  }
}

print "unhacha 1.1\n" . ("-" x 11) . "\n";
die("Must give a filename.\n" .
    "Usage $0 filename1.0 finename2.0\n" .
    "Ex: $0 *.0\n") unless (@ARGV);
foreach my $sFileName (@ARGV) {
  my $oResult = getHeader($sFileName);
  if ($oResult->{'ok'}) {
    my $iExtra = $oResult->{'header'};
    $sFileName =~ s/\.0$//;
    my $iIndex = 0;
    unlink($oResult->{'name'});
    while (writeToFile($oResult->{'name'}, $sFileName . "." . $iIndex, $iExtra) > -1 ) {
      $iExtra = 0;
      $iIndex++;
    }
    print "$sFileName ($iIndex) -> OK\n";
  } else {
    print $oResult->{'msg'} . "\n";
  }
}
