# Erstellt 8 kB Firmware Datei (für 27C64) aus Datei für 27C512 EPROM
use strict;
use warnings;

my $args = @ARGV;
my $fwname  =uc(pop @ARGV) or die "Filename missing!\n";

my $soc = 0xc000;
my $ivec= 0xffe8;

my $datenblock="";
my $tmp="";

open(DATEI,$fwname) or die "File open error: $!\n";
binmode(DATEI);
seek(DATEI,$soc,0);                                       # Von Start of Code suchen
my $gelesen = read(DATEI,$datenblock,0x3fe8);              # Bis Interruptvektoren lesen
seek(DATEI,$ivec,0);
$gelesen = read(DATEI,$tmp,24);                           # Interruptvektoren lesen
$datenblock.=$tmp;
close(DATEI);

open(DATEI,">16k_".$fwname) or die "File open error: $!\n";
binmode(DATEI);
print DATEI $datenblock;
close(DATEI);

