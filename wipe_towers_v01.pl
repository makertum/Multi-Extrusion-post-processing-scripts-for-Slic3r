# WIPE TOWERS v01
# PERL POSTPROCESSOR FOR ADDING WIPE TOWERS TO SLIC3R
# YUNOMAKE.COM
# (c) Moritz Walter 2015

#!/usr/bin/perl -i
use strict;
use warnings;
use Math::Round;
use POSIX qw[ceil floor];
use List::Util qw[min max];
use constant PI    => 4 * atan2(1, 1);

# printer parameters with default values

my $nozzleDiameter=0.4;
my $filamentDiameter=1.75;
my $extrusionMultiplier=1.0;
my $firstLayerExtrusionMultiplier=4.0;
my $extrusionWidth=$nozzleDiameter;
my $layerHeight=0.2;
my $firstLayerHeight=0.1;
my $retractionLength=5;
my $toolChangeRetractionLength=5;

my $bedWidth=160;
my $bedDepth=165;
my $extruders=2;

# other params
my $travelLift=1;

# wipe tower parameters with default values

my $wipeTowerX=80;
my $wipeTowerY=155;
my $wipeTowerW=10;
my $wipeTowerH=10;
my $wipeTowerSpacing=20;
my $wipeTowerLoops=5;
my $wipeTowerBrimLoops=7;

# wipe parameters with default values

my $wipeOffset=2;
my $purgeOffset=2;
my $wipeLift=5;
my $purgeAmount=3;

# printing parameters with default parameters, feedrates are multiplied by 60 on import for converting them from mm/s to mm/min

my $retractionFeedrate=75*60;
my $travelFeedrate=150*60;
my $printFeedrate=30*60;
my $extrusionFeedrate=25*60;

# state variables, keeping track of whats happening inside the G-code

my @extruderUsed=(0,0,0,0); # counts how often an extruder is used

my $gcodeF=4500;
my $gcodeActiveExtruder=0;
my @gcodeX=();
my @gcodeY=();
my $gcodeZ=0;
my $lastGcodeZ=0;
my @gcodeE=();
my @gcodeRetraction=();
my $gcodeAbsolutePositioning=0;

# state variables, keeping track of what we're doing

my $currentF=4500;
my $currentE=0;
my $currentX=0;
my $currentY=0;

my $absolutePositioning=1;
my $absoluteExtrusion=0;

my $line=1;
my $towerLayer=0;
my $wipe=[0,0];

# processing variables

my $layer = 0;
my $start = 0;
my $end = 0;

my @linesByExtruder=();
my @endOfLayerLines=();

my $bypass=0;

for(my $i=0;$i<$extruders;$i++){
	$linesByExtruder[$i]=();
	$gcodeX[$i]=0;
	$gcodeY[$i]=0;
	$gcodeE[$i]=0;
	$gcodeRetraction[$i]=0;
}

##########
# MAIN LOOP
##########

while (<>) {
	if($start==0){
  	readParams($_);
		evaluateLine($_);
		print;
	}elsif($end==1){
  	print; # just print out everything after the end code marker
	}elsif (/^T(\d)/){
		evaluateLine($_);
	}elsif(/^; next layer/){
		# do nothing, strips line by not printing it back
	}elsif(/^; tool change/){
		# do nothing, strips line by not printing it back
  }elsif(/^M204/){
		push(@{$linesByExtruder[$gcodeActiveExtruder]},$_); # acceleration changes are sorted into extruder arrays
  }elsif(/^G[01]( X(-?\d*\.?\d*))?( Y(-?\d*\.?\d*))?( Z(-?\d*\.?\d*))?( E(-?\d*\.?\d*))?/){ # regular move
  	if($6){ # move contains z-move, interpreted as layer change if not happening before the start code marker
  		insertSortedLayer(); # inserts all moves of the current layer, this also inserts the wipe towers on tool chage
  		evaluateLine($_); # keeps the g-code tracker aligned
  		print; # copying z-move
  		print("; next layer\n"); # insert next layer marker because having stripped it before
  		$layer++; # count layer
  	}else{
			push(@{$linesByExtruder[$gcodeActiveExtruder]},$_); # moves that do not contain z-moves are sorted into the extruder arrays
  	}
  }elsif(/^; end of g-code/){
  	$end=1;
  	insertSortedLayer(); # the last layer is not followed by a layer change, thats why we have to insert it here
	  print;
  }else{ # all the other gcodes, such as temperature changes, fan on/off, the config summary, etc.. are shoved to the end of a layer
		push(@endOfLayerLines,$_);
	}
}

##########
# PRINT TOWER
##########

sub squareTowerEL{ # returns the gcode for printing a wipe tower
	my $e=$_[0];
	my $l=$_[1];
	my $x=$wipeTowerX+$e*$wipeTowerSpacing;
	my $y=$wipeTowerY;
	my $gcode="";
	
	$gcode.=comment("printing square tower with layer height $l");
	my $travelPoints=generatePreTravelPointsEN($e,$layer);
	
	#$gcode.=lift($travelLift);
	$gcode.=travelToXYF($travelPoints->[0]->[0],$travelPoints->[0]->[1],$travelFeedrate);
	#$gcode.=lower($travelLift);
	$gcode.=travelToXYF($travelPoints->[1]->[0],$travelPoints->[1]->[1],$travelFeedrate);
	
	if($layer==0){
		$gcode.=comment("printing brim");
		for(my $loop=0;$loop<$wipeTowerBrimLoops;$loop++){
			my $brimPoints=baseCornerBrimPointsELN($e,$loop,$layer);
			$gcode.=travelToXYF($brimPoints->[0]->[0],$brimPoints->[0]->[1],$travelFeedrate);
			if($loop==0){
				$gcode.=extrudeEF(-$gcodeRetraction[$e], $retractionFeedrate); #$retractionLength
			}
			for(my $p=1;$p<5;$p++){
				$gcode.=extrudeToXYFL($brimPoints->[$p]->[0],$brimPoints->[$p]->[1],$printFeedrate,$l);
			}
			if($loop==$wipeTowerBrimLoops-1){
				$gcode.=extrudeEF($gcodeRetraction[$e], $retractionFeedrate); #-$retractionLength
			}
		}
	}
	
	$gcode.=comment("printing loops");
	for(my $loop=0;$loop<$wipeTowerLoops;$loop++){
		my $printPoints=baseCornerPointsELN($e,$loop,$layer);
		$gcode.=travelToXYF($printPoints->[0]->[0],$printPoints->[0]->[1],$travelFeedrate);
		if($loop==0){
			$gcode.=extrudeEF(-$gcodeRetraction[$e], $retractionFeedrate); #$retractionLength
		}
		for(my $p=1;$p<5;$p++){
			$gcode.=extrudeToXYFL($printPoints->[$p]->[0],$printPoints->[$p]->[1],$printFeedrate,$l);
		}
		if($loop==$wipeTowerLoops-1){
			$gcode.=extrudeEF($gcodeRetraction[$e], $retractionFeedrate); #-$retractionLength
		}
	}
	return $gcode;
}

##########
# MATH
##########

sub digitize { # cut floats to size
	my $num=$_[0];
	my $digits=$_[1];
  my $factor=10**$digits;
  return (round($num*$factor))/$factor;
}

sub dist{ # calculate distances between 2d points
	my $x1=$_[0];
	my $y1=$_[1];
	my $x2=$_[2];
	my $y2=$_[3];
	return sqrt(($x2-$x1)**2+($y2-$y1)**2);
}

sub extrusionXYXY{ # calculate the extrusion length for a move from (x1,y1) to (x2,y2)
	my $x1=$_[0];
	my $y1=$_[1];
	my $x2=$_[2];
	my $y2=$_[3];
  my $filamentArea=$filamentDiameter*$filamentDiameter/4*PI;
  my $lineLength=dist($x1,$y1,$x2,$y2);
  my $eDist=$lineLength*$extrusionWidth/$filamentArea;
  if($layer==0){
  	$eDist*=$firstLayerHeight;
	  $eDist*=$firstLayerExtrusionMultiplier;
	}else{
  	$eDist*=$layerHeight;
	  $eDist*=$extrusionMultiplier;
	}
  return digitize($eDist,4);
}

sub extrusionXYXYL{ # calculate the extrusion length for a move from (x1,y1) to (x2,y2)
	my $x1=$_[0];
	my $y1=$_[1];
	my $x2=$_[2];
	my $y2=$_[3];
	my $l=$_[4];
  my $filamentArea=$filamentDiameter*$filamentDiameter/4*PI;
  my $lineLength=dist($x1,$y1,$x2,$y2);
  my $eDist=$lineLength*$extrusionWidth/$filamentArea;
  $eDist*=$l;
  if($layer==0){
	  $eDist*=$firstLayerExtrusionMultiplier;
	}else{
	  $eDist*=$extrusionMultiplier;
	}
  return digitize($eDist,4);
}

sub extrusionXY { # calculate the extrusion length for a move from the current extruder position to (x,y)
	my $x=$_[0];
	my $y=$_[1];
  if($absolutePositioning){
    return extrusionXYXY($currentX, $currentY, $x, $y);
  }else{
    return extrusionXYXY(0, 0, $x, $y);
  }
}
sub extrusionXYL { # calculate the extrusion length for a move from the current extruder position to (x,y) taking a layer height
	my $x=$_[0];
	my $y=$_[1];
	my $l=$_[2];
  if($absolutePositioning){
    return extrusionXYXYL($currentX, $currentY, $x, $y, $l);
  }else{
    return extrusionXYXYL(0, 0, $x, $y, $l);
  }
}

sub baseCornerPointsELN{ # calculates the corner points of the wipe tower
	my $e=$_[0];
	my $l=$_[1];
	my $n=$_[2];
	my $x=$wipeTowerX+$e*$wipeTowerSpacing;
	my $y=$wipeTowerY;
	my $extrusionWidthOffset=$l*$extrusionWidth;
	my $points=[
		[$x-$wipeTowerW/2+$extrusionWidthOffset,$y-$wipeTowerH/2+$extrusionWidthOffset],
		[$x-$wipeTowerW/2+$extrusionWidthOffset,$y+$wipeTowerH/2-$extrusionWidthOffset],
		[$x+$wipeTowerW/2-$extrusionWidthOffset,$y+$wipeTowerH/2-$extrusionWidthOffset],
		[$x+$wipeTowerW/2-$extrusionWidthOffset,$y-$wipeTowerH/2+$extrusionWidthOffset]
	];
	my $result=[
		$points->[$n%4],
		$points->[($n+1)%4],
		$points->[($n+2)%4],
		$points->[($n+3)%4],
		$points->[$n%4]
	];
	return $result;
}


sub baseCornerBrimPointsELN{ # calculates the corner points of the wipe tower
	my $e=$_[0]; #extruder
	my $l=$_[1]; #loops
	my $n=$_[2]; #layer n
	my $x=$wipeTowerX+$e*$wipeTowerSpacing;
	my $y=$wipeTowerY;
	my $extrusionWidthOffset=$l*$extrusionWidth-$wipeTowerBrimLoops*$extrusionWidth;
	my $points=[
		[$x-$wipeTowerW/2+$extrusionWidthOffset,$y-$wipeTowerH/2+$extrusionWidthOffset],
		[$x-$wipeTowerW/2+$extrusionWidthOffset,$y+$wipeTowerH/2-$extrusionWidthOffset],
		[$x+$wipeTowerW/2-$extrusionWidthOffset,$y+$wipeTowerH/2-$extrusionWidthOffset],
		[$x+$wipeTowerW/2-$extrusionWidthOffset,$y-$wipeTowerH/2+$extrusionWidthOffset]
	];
	my $result=[
		$points->[$n%4],
		$points->[($n+1)%4],
		$points->[($n+2)%4],
		$points->[($n+3)%4],
		$points->[$n%4]
	];
	return $result;
}

sub generatePreTravelPointsEN{ # calculates the travel points for approaching a wipe tower
	my $e=$_[0];
	my $n=$_[1];
	my $x=$wipeTowerX+$e*$wipeTowerSpacing;
	my $y=$wipeTowerY;
	my $points=[
		[
			[$x-$wipeTowerW/2-$wipeOffset,$y-$wipeTowerH/2-$wipeOffset],
			[$x-$wipeTowerW/2-$wipeOffset,$y-$wipeTowerH/2-$wipeOffset] # duplicate
		],
		[
			[$x-$wipeTowerW/2-$wipeOffset,$y-$wipeTowerH/2-$wipeOffset],
			[$x-$wipeTowerW/2-$wipeOffset,$y+$wipeTowerH/2+$wipeOffset]
		],
		[
			[$x+$wipeTowerW/2+$wipeOffset,$y-$wipeTowerH/2-$wipeOffset],
			[$x+$wipeTowerW/2+$wipeOffset,$y+$wipeTowerH/2+$wipeOffset]
		],
		[
			[$x+$wipeTowerW/2+$wipeOffset,$y-$wipeTowerH/2-$wipeOffset],
			[$x+$wipeTowerW/2+$wipeOffset,$y-$wipeTowerH/2-$wipeOffset] # duplicate
		]
	];
	return $points->[$n%4];
}

sub generatePostTravelPoints{ # calculates the travel points for leaving a wipe tower
	my $x=$_[0];
	my $y=$_[1];
	my $n=$_[2];
	my $points=[
		[
			[$x+$wipeTowerW/2+$wipeOffset,$y+$wipeTowerH/2+$wipeOffset],
			[$x+$wipeTowerW/2+$wipeOffset,$y-$wipeTowerH/2-$wipeOffset]
		],
		
		[
			[$x+$wipeTowerW/2+$wipeOffset,$y-$wipeTowerH/2-$wipeOffset],
			[$x+$wipeTowerW/2+$wipeOffset,$y-$wipeTowerH/2-$wipeOffset] # duplicate
		],
		[
			[$x-$wipeTowerW/2-$wipeOffset,$y-$wipeTowerH/2-$wipeOffset],
			[$x-$wipeTowerW/2-$wipeOffset,$y-$wipeTowerH/2-$wipeOffset] # duplicate
		],
		[
			[$x-$wipeTowerW/2-$wipeOffset,$y+$wipeTowerH/2+$wipeOffset],
			[$x-$wipeTowerW/2-$wipeOffset,$y-$wipeTowerH/2-$wipeOffset]
		],
	];
	return $points->[$n%4];
}

sub generatePurgePosition{
	my $x=$_[0];
	my $y=$_[1];
	my $n=$_[2];
	my $positions=[
		[$x-$purgeOffset,$y-$purgeOffset],
		[$x-$purgeOffset,$y+$purgeOffset],
		[$x+$purgeOffset,$y+$purgeOffset],
		[$x+$purgeOffset,$y-$purgeOffset]
	];
	return $positions->[$n%4];
}



##########
# TRAVEL
##########

sub travelToZ{ # appends a trave move
	my $z=$_[0];
  return "G1 Z".digitize($z,4)."\n";
}

sub travelToXYF{ # appends a trave move
	my $x=$_[0];
	my $y=$_[1];
	my $f=$_[2];
	
  if($absolutePositioning){
    $currentX=$x;
    $currentY=$y;
  }else{
    $currentX+=$x;
    $currentY+=$y;
  }
  $currentF=$f;
	
  return "G1 X".digitize($x,4)." Y".digitize($y,4)." F".$f."\n";
}

sub travelToXY{ # appends a trave move
	my $x=$_[0];
	my $y=$_[1];
	
  if($absolutePositioning){
    $currentX=$x;
    $currentY=$y;
  }else{
    $currentX+=$x;
    $currentY+=$y;
  }
  
  return "G1 X".digitize($x,4)." Y".digitize($y,4)."\n";
}

sub lift{
	my $gcode="";
  $gcode.=relativePositioning();
  $gcode.=travelToZ($_[0]);
  $gcode.=absolutePositioning();
  return $gcode;
}

sub lower{
	my $gcode="";
  $gcode.=relativePositioning();
  $gcode.=travelToZ(-$_[0]);
  $gcode.=absolutePositioning();
  return $gcode;
}

##########
# EXTRUDE
##########

sub extrudeEF{ # appends an extrusion (=printing) move
	my $e=$_[0];
	my $f=$_[1];
  $currentE+=$e;
  if($absoluteExtrusion){
  	return "G1 E".digitize($currentE,4)." F".digitize($f,4)."\n";
  }else{
    return "G1 E".digitize($e,4)." F".digitize($f,4)."\n";
  }
}

sub extrudeE{ # appends an extrusion (=printing) move
	my $e=$_[0];
  $currentE+=$e;
  if($absoluteExtrusion){
    return "G1 E".digitize($currentE,4)."\n";
  }else{
    return "G1 E".digitize($e,4)."\n";
  }
}

sub extrudeToXYF{
	my $x=$_[0];
	my $y=$_[1];
	my $f=$_[2];
  my $extrusionLength=extrusionXY($x,$y);
  $currentE+=$extrusionLength;
  
  if($absolutePositioning){
    $currentX=$x;
    $currentY=$y;
  }else{
    $currentX+=$x;
    $currentY+=$y;
  }
  $currentF=$f;
  
  if($absoluteExtrusion){
    return "G1 X".digitize($x,4)." Y".digitize($y,4)." E".digitize($currentE,4)." F".digitize($f,4)."\n";
  }else{
    return "G1 X".digitize($x,4)." Y".digitize($y,4)." E".digitize($extrusionLength,4)." F".digitize($f,4)."\n";
  }
}

sub extrudeToXYFL{
	my $x=$_[0];
	my $y=$_[1];
	my $f=$_[2];
	my $l=$_[3];
  my $extrusionLength=extrusionXYL($x,$y,$l);
  $currentE+=$extrusionLength;
  
  if($absolutePositioning){
    $currentX=$x;
    $currentY=$y;
  }else{
    $currentX+=$x;
    $currentY+=$y;
  }
  $currentF=$f;
  
  if($absoluteExtrusion){
    return "G1 X".digitize($x,4)." Y".digitize($y,4)." E".digitize($currentE,4)." F".digitize($f,4)."\n";
  }else{
    return "G1 X".digitize($x,4)." Y".digitize($y,4)." E".digitize($extrusionLength,4)." F".digitize($f,4)."\n";
  }
}

sub extrudeToXY{ # appends an extrusion (=printing) move
	my $x=$_[0];
	my $y=$_[1];
  my $extrusionLength=extrusionXY($x,$y);
  $currentE+=$extrusionLength;
  
  if($absolutePositioning){
    $currentX=$x;
    $currentY=$y;
  }else{
    $currentX+=$x;
    $currentY+=$y;
  }
  
  if($absoluteExtrusion){
    return "G1 X".digitize($x,4)." Y".digitize($y,4)." E".digitize($currentE,4)."\n";
  }else{
    return "G1 X".digitize($x,4)." Y".digitize($y,4)." E".digitize($extrusionLength,4)."\n";
  }
}

sub extrudeToXYL{ # appends an extrusion (=printing) move, respecting the layer height
	my $x=$_[0];
	my $y=$_[1];
	my $l=$_[2];
  my $extrusionLength=extrusionXYL($x,$y,$l);
  $currentE+=$extrusionLength;
  
  if($absolutePositioning){
    $currentX=$x;
    $currentY=$y;
  }else{
    $currentX+=$x;
    $currentY+=$y;
  }
  
  if($absoluteExtrusion){
    return "G1 X".digitize($x,4)." Y".digitize($y,4)." E".digitize($currentE,4)."\n";
  }else{
    return "G1 X".digitize($x,4)." Y".digitize($y,4)." E".digitize($extrusionLength,4)."\n";
  }
}

##########
# OTHER GCODES
##########


sub absolutePositioning{ # changes coordinate mode and appends the necessary G-code
  $absolutePositioning=1;
  return "G90 ; set absolute positioning\n";
}

sub relativePositioning{ # changes coordinate mode and appends the necessary G-code
  $absolutePositioning=0;
  return "G91 ; set relative positioning\n";
}

sub absoluteExtrusion{ # changes extrusion mode and appends the necessary G-code
  $absoluteExtrusion=1;
  return "M82 ; set extruder to absolute mode\n";
}
sub relativeExtrusion{ # changes extrusion mode and appends the necessary G-code
  $absoluteExtrusion=0;
  return "M83 ; set extruder to relative mode\n";
}

sub selectExtruder{ # switches the used extruder and appends the necessary G-code, does NOT change $activeExtruder since we want to switch back to $activeExtruder
	return "T".$_[0]."\n";
}

sub dwell{ # appends a dwelling G-code with the argument as seconds
  return "G4 S".$_[0]."\n";
}

sub comment{ # appends the argument to the currently read G-code line and comments it out with a "; "
  return "; ".$_[0]."\n";
}


##########
# PROCESSING
##########


sub evaluateLine{
	my $e=$gcodeActiveExtruder;
	if($#_==1){
		$e=$_[1];
	}
	if ($_[0]=~/^T(\d)/){
		$gcodeActiveExtruder=$1;
  }elsif(/^; next layer/){
  	$start=1;
  }elsif(/^G90/){
  	$gcodeAbsolutePositioning=1;
  }elsif(/^G91/){
  	$gcodeAbsolutePositioning=0;
  }elsif(/^G28/){
  	$lastGcodeZ=0;
  	$gcodeZ=0;
  }elsif(/^G29/){
  	$lastGcodeZ=0;
  	$gcodeZ=0;
  }elsif($_[0]=~/^G[01]( X(-?\d*\.?\d*))?( Y(-?\d*\.?\d*))?( Z(-?\d*\.?\d*))?( E(-?\d*\.?\d*))?/){
  	if($2){
  		if($gcodeAbsolutePositioning){
  			$gcodeX[$e]=$2;
  		}else{
  			$gcodeX[$e]+=$2;
  		}
  	}
  	if($4){
  		if($gcodeAbsolutePositioning){
  			$gcodeY[$e]=$4;
  		}else{
  			$gcodeY[$e]+=$4;
  		}
  	}
  	if($6){
  		if($start){
  			$lastGcodeZ=$gcodeZ;
  		}
  		if($gcodeAbsolutePositioning){
  			$gcodeZ=$6;
  		}else{
  			$gcodeZ+=$6;
  		}
  	}
  	if($8){ # keeps track of relative extruder moves for each extruder, aiming to support absolute extrusion in the future
  		if(!$2 && !$4 && !$6){
  			if($8<0){
					$gcodeRetraction[$e]+=$8;
  			}else{
  				if($8>0){
  					if($8>-$gcodeRetraction[$e]){
  						$gcodeRetraction[$e]=0;
  					}else{
							$gcodeRetraction[$e]+=$8;
  					}
			  	}
			  }
	  	}
  	}
  }
}

sub insertSortedLayer{
	for(my $e=0;$e<$extruders;$e++){
		#if($#{$linesByExtruder[$e]}>-1){
			print("; tool change\n");
			print "T".$e."\n";
			insertWipeTowerE($e);
			for(my $i=0; $i<=$#{$linesByExtruder[$e]};$i++){
				evaluateLine($linesByExtruder[$e][$i],$e);
				print($linesByExtruder[$e][$i]);
			}
			@{$linesByExtruder[$e]}=();
		#}else{
			#print("; omitted tool change\n");
		#}
	}
	if($#endOfLayerLines>-1){
		print("; end of layer lines\n");
		for(my $i=0; $i<=$#endOfLayerLines;$i++){
			print($endOfLayerLines[$i]);
		}
		@endOfLayerLines=();
	}
}

sub insertWipeTowerE{
	my $e=$_[0];
	my $l=$gcodeZ-$lastGcodeZ;
	if($l>0){
		print squareTowerEL($e,$l);
		print lift($travelLift);
		print travelToXYF($gcodeX[$e],$gcodeY[$e],$travelFeedrate);
		print lower($travelLift);
	}else{
		print "; omitting wipe tower\n";
	}
}

sub readParams{ # collecting params
	if($_[0]=~/nozzleDiameter=(\d*\.?\d*)/){
		$nozzleDiameter=$1*1.0;
	}
	if($_[0]=~/filamentDiameter=(\d*\.?\d*)/){
		$filamentDiameter=$1*1.0;
	}
	if($_[0]=~/extrusionWidth=(\d*\.?\d*)/){
		$extrusionWidth=$1*1.0;
	}
	if($_[0]=~/extrusionMultiplier=(\d*\.?\d*)/){
		$extrusionMultiplier=$1*1.0;
	}
	if($_[0]=~/firstLayerExtrusionMultiplier=(\d*\.?\d*)/){
		$firstLayerExtrusionMultiplier=$1*1.0;
	}
	if($_[0]=~/layerHeight=(\d*\.?\d*)/){
		$layerHeight=$1*1.0;
	}
	if($_[0]=~/firstLayerHeight=(\d*\.?\d*)/){
		$firstLayerHeight=$1*1.0;
	}
	if($_[0]=~/retractionLength=(\d*\.?\d*)/){
		$retractionLength=$1*1.0;
	}
	if($_[0]=~/toolChangeRetractionLength=(\d*\.?\d*)/){
		$toolChangeRetractionLength=$1*1.0;
	}
	if($_[0]=~/bedWidth=(\d*\.?\d*)/){
		$bedWidth=$1*1.0;
	}
	if($_[0]=~/bedDepth=(\d*\.?\d*)/){
		$bedDepth=$1*1.0;
	}
	if($_[0]=~/extruders=(\d*\.?\d*)/){
		$extruders=$1*1.0;
	}
	if($_[0]=~/wipeTowerX=(\d*\.?\d*)/){
		$wipeTowerX=$1*1.0;
	}
	if($_[0]=~/wipeTowerY=(\d*\.?\d*)/){
		$wipeTowerY=$1*1.0;
	}
	if($_[0]=~/wipeTowerW=(\d*\.?\d*)/){
		$wipeTowerW=$1*1.0;
	}
	if($_[0]=~/wipeTowerH=(\d*\.?\d*)/){
		$wipeTowerH=$1*1.0;
	}
	if($_[0]=~/wipeTowerSpacing=(\d*\.?\d*)/){
		$wipeTowerSpacing=$1*1.0;
	}
	if($_[0]=~/wipeTowerLoops=(\d*\.?\d*)/){
		$wipeTowerLoops=$1*1.0;
	}
	if($_[0]=~/wipeTowerBrimLoops=(\d*\.?\d*)/){
		$wipeTowerBrimLoops=$1*1.0;
	}
	if($_[0]=~/wipeOffset=(\d*\.?\d*)/){
		$wipeOffset=$1*1.0;
	}
	if($_[0]=~/purgeOffset=(\d*\.?\d*)/){
		$purgeOffset=$1*1.0;
	}
	if($_[0]=~/wipeLift=(\d*\.?\d*)/){
		$wipeLift=$1*1.0;
	}
	if($_[0]=~/travelLift=(\d*\.?\d*)/){
		$travelLift=$1*1.0;
	}
	if($_[0]=~/purgeAmount=(\d*\.?\d*)/){
		$purgeAmount=$1*1.0;
	}
	if($_[0]=~/retractionFeedrate=(\d*\.?\d*)/){
		$retractionFeedrate=$1*60.0;
	}
	if($_[0]=~/travelFeedrate=(\d*\.?\d*)/){
		$travelFeedrate=$1*60.0;
	}
	if($_[0]=~/printFeedrate=(\d*\.?\d*)/){
		$printFeedrate=$1*60.0;
	}
	if($_[0]=~/extrusionFeedrate=(\d*\.?\d*)/){
		$extrusionFeedrate=$1*60.0;
	}
}
