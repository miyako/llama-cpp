#DECLARE()->$process : Object
var $number; $state; $time; $mode; $ID; $origin : Integer
var $name : Text
$number:=Current process:C322
$state:=-100
PROCESS PROPERTIES:C336($number; $name; $state; $time; $mode; $ID; $origin)
$process:={number: $number; ID: $ID; name: $name; type: $origin; state: $state; available: ($name#"") && ($state#-100) && ($ID#0) && ($origin=5)}
