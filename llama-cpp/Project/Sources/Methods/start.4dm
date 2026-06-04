//%attributes = {"invisible":true,"preemptive":"capable"}
#DECLARE($options : Object; $formula : 4D:C1709.Function)

var $model : cs:C1710._Model
$model:=cs:C1710._Model.new($options.port; $options.huggingfaces; $options.options; $formula; $options.event)

If ($model.offline)\
 || ((OB Instance of:C1731($options.options.models_preset; 4D:C1709.File))\
 && ($options.options.models_preset.exists))\
 || ((OB Instance of:C1731($options.options.models_dir; 4D:C1709.Folder))\
 && ($options.options.models_dir.exists))
	$model.start()
End if 