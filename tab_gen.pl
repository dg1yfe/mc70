
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
     if($i != $table_length-1)
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