# ****************************************************************************
#
#     MC70 - Firmware for the Motorola MC micro trunking radio
#            to use it as an Amateur-Radio transceiver
#
#     Copyright (C) 2004 - 2011  Felix Erckenbrecht, DG1YFE
#
#      This file is part of MC70.
#
#      MC70 is free software: you can redistribute it and/or modify
#      it under the terms of the GNU General Public License as published by
#      the Free Software Foundation, either version 3 of the License, or
#      (at your option) any later version.
#
#      MC70 is distributed in the hope that it will be useful,
#      but WITHOUT ANY WARRANTY; without even the implied warranty of
#      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#      GNU General Public License for more details.
#
#      You should have received a copy of the GNU General Public License
#      along with MC70.  If not, see <http://www.gnu.org/licenses/>.
#
#
#
# ****************************************************************************

use strict;
use Math::Round;

my $i;
my $j;
my @y;
my @err;
my @err1;
my $print_err = 1;

my $table_length = 256;
my $minval = 0;
my $maxval = 1;

my $offset= 0.575;
#my $offset= ($maxval-$minval)/2 ;

my $minamp = 0.1;
my $maxamp = 0.9;

my $prefix = "dw";
my $scale  = 1;

my $columns = 8;
#################
my @tridac = (1.31,1.34,1.66,1.98,2.48,2.92,3.26,3.64,3.88);
my @portval = (0x6000, 0x4000, 0x2000, 0x6020, 0, 0x6040, 0x2020, 0x4040, 0x6060);

#my $offset= 5 ;
my $amplitude = ($maxamp-$minamp)/2;

my @tridac_range;
my $val;

$val=$tridac[0];
for($i=0;$i<9;$i++)
{
    $tridac[$i]=$tridac[$i] - $val;
}

$val=$tridac[8];
for($i=0;$i<9;$i++)
{
    $tridac[$i]=$tridac[$i] / $val;
    printf("%01.3f\n",$tridac[$i]);
}


for($i=0;$i<8;$i++)
{
    push(@tridac_range, $tridac[$i]+($tridac[$i+1] - $tridac[$i])/2);
}

$j=0;

# print all DAC table entries
for($i=0;$i<$table_length;$i++)
{
    $val = $i/$table_length;
    while(($val>$tridac_range[$j]) && $j<8)
    {
        $j++;
    }

    $y[$i]=$j;
    $err[$i]=($tridac[$j]-$i/$table_length)*256;
    printf("%4.3f - %4.3f (%d / %d))\n",$val,$tridac_range[$j],$j,$i);
#    print $y[$i]."\n";
}


for($i=0;$i<$table_length;$i++)
{
     if($i != $table_length-4)
     {
         $err1[$i]=($tridac[$y[$i+1]]-$i/$table_length)*256;
     }
     else
     {
         $err1[$i]=($tridac[$y[$i]]-$i/$table_length)*256;
     }
}

if ($print_err==1)
{
    $prefix = "db";
    $columns =  16;

    for($i=0;$i<$table_length/$columns;$i++)
    {
        print "\t\t.".$prefix."  ";
        for($j=0;$j<$columns;$j++)
        {
            printf("%3d,",$err[$i*$columns+$j]*$scale+32);
        }
        print "\n";
    }

    printf("Err 1:\n");
    for($i=0;$i<$table_length/$columns;$i++)
    {
        print "\t\t.".$prefix."  ";
        for($j=0;$j<$columns;$j++)
        {
            printf("%3d,",$err1[$i*$columns+$j]*$scale+32);
        }
        print "\n";
    }
}