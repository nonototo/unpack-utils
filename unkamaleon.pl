#!/usr/bin/perl -w
##############################################################################
#
# $Id: unkamaleon.pl,v 1.1 2002/09/24 16:07:24 xabi <mail(at)xa.bi> Exp $

use strict;
sub getHeader {
  my $sFile = $_[0];
  return { 'ok' => 0, 'msg' => "Error [$sFile] does not exist."} unless (-f $sFile);
  open(IN, $sFile) || return { 'ok' => 0, 'msg' => "Could not open file [$sFile]."};
  binmode(IN);
  my $sHeader = "";
  seek(IN, (stat($sFile))[7] - 19, 0);
  read(IN, $sHeader, 19);
  close(IN);
  if ($sHeader =~ /(\d\d\d\d\d\d\d\d\d\d)<-LISTA->/) {
    return { 'ok' => 1, 'iskamaleon' => 1, 'size' => $1 };
  } else {
    return { 'ok' => 1, 'iskamaleon' => 0 };
  }
}

sub getResourceList {
  my ($sFile, $iSize) = @_;
  my @aResult = ();
  my $sHeader;
  my $iCount;
  my $sResultFile;
  my $sOrgFile;
  my $iBytes;
  my $iExtraHeader;

  open(IN, $sFile);
  binmode(IN);
  seek(IN, $iSize, 0);
  read(IN, $sHeader, (stat($sFile))[7] - $iSize);
  close(IN);
  my $sTmp = "";
  my $iStatus = 1;
  my $sCount;
  foreach my $iChar (unpack('C*', $sHeader)) {
    $iCount++;
    if ($iStatus == 1) {      # Waiting for result file
      $iStatus = 2 if ($iCount == 1);
    } elsif ($iStatus == 2) { # Reading result filename
      if ($iChar == 0) {
        $sResultFile = $sTmp;
        $sTmp = "";
        $iStatus = 3;
      } else {
        $sTmp .= chr($iChar);
      }
    } elsif ($iStatus == 3) { # Waiting for org_file
      $iStatus = 4 if ($iCount == 292);
    } elsif ($iStatus == 4){
      if ($iChar == 0) {
        $sOrgFile = $sTmp;
        $sTmp = "";
        $iStatus = 5;
      } else {
        $sTmp .= chr($iChar);
      }
    } elsif ($iStatus == 5) { # Waiting for Size
      $iStatus = 6 if ($iCount == 548);
    } elsif ($iStatus == 6) { # Fisrt Byte
      $iBytes = $iChar;
      $iStatus = 7;
    } elsif ($iStatus == 7) {
      $iBytes += $iChar * 256;
      $iStatus = 8;
    } elsif ($iStatus == 8) {
      $iBytes += $iChar * 256 * 256;
      $iStatus = 9;
    } elsif ($iStatus == 9) {
      $iBytes += $iChar * 256 * 256 * 256;
      $iStatus = 10;

    } elsif ($iStatus == 10) { # Waiting for Size
      $iStatus = 11 if ($iCount == 556);
    } elsif ($iStatus == 11) { # Fisrt Byte
      $iExtraHeader = $iChar;
      $iStatus = 12;
    } elsif ($iStatus == 12) {
      $iExtraHeader += $iChar * 256;
      $iStatus = 13;
    } elsif ($iStatus == 13) {
      $iExtraHeader += $iChar * 256 * 256;
      $iStatus = 14;
    } elsif ($iStatus == 14) {
      $iExtraHeader += $iChar * 256 * 256 * 256;
      $iStatus = 1;
      $iCount = 0;
      push(@aResult, {'from'=>$sOrgFile, 'to'=>$sResultFile, 'size'=>$iBytes, 'extra'=>$iExtraHeader});
    }
  }
  return @aResult;
}

sub writeToFile {
  my $hData = $_[0];
  my $sBuff;
  my $iBufferSize = 100 * 1024;

  if (-f $hData->{'from'}) {
    if ((stat($hData->{'from'}))[7] < $hData->{'size'}) {
      print "  +-- ERROR. File [" . $hData->{'from'} . "] is too small.\n";
      return -1;
    } else {
      open(IN, $hData->{'from'});
      open(OUT, ">>" . $hData->{'to'});
      binmode(IN);
      binmode(OUT);
      seek(IN, $hData->{'extra'}, 0);
      my $iFullSize = $hData->{'size'} - $hData->{'extra'};
      $iBufferSize = $iFullSize if ($iBufferSize > $iFullSize);
      while (read(IN, $sBuff, $iBufferSize)) {
        print OUT  $sBuff;
        $iFullSize -= $iBufferSize;
        $iBufferSize = $iFullSize if ($iBufferSize > $iFullSize);
      }
      close(OUT);
      close(IN);
    }
    return $hData->{'size'} - $hData->{'extra'};
  } else {
    print "  +-- ERROR. Could not find part [" . $hData->{'from'} . "].\n";
    return 0
  }
}

print "unkamaleon 1.1\n" . ("-" x 11) . "\n";
die("Must give a filename.\n" .
    "Usage $0 filename1 finename2 ...\n" .
    "Ex: $0 *\n") unless (@ARGV);
foreach my $sFileName (@ARGV) {
  my $oResult = getHeader($sFileName);
  if ($oResult->{'ok'}) {
    if ($oResult->{'iskamaleon'}) {
      print "Processing [$sFileName]:\n";
      my @aResult = getResourceList($sFileName, $oResult->{'size'});
      if (@aResult) {
        foreach my $hPart (@aResult) {
          unlink($hPart->{'to'});
        }
        foreach my $hPart (@aResult) {
          my $iBytesWritten = writeToFile($hPart);
          if ($iBytesWritten > 0 ) {
            print "  +-- " . $hPart->{'from'} . " --> " . $hPart->{'to'} . " (" . $iBytesWritten . ")\n";
          } else {
            print "      +-- ERROR. File [" . $hPart->{'to'} . "] is Broken.\n";
            unlink($hPart->{'to'});
            last;
          }
        }
      } else {
        print "  +-- Could not find index.\n";
      }
    }
  } else {
    print $oResult->{'msg'} . "\n";
  }
}
