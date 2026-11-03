Class constructor()

Function sha256($file : 4D.File; $options : Object) : Object
	var $blob : Blob
	$blob:=$file.getContent()
	return {success: True; algorithm: "sha256"; digest: Generate digest($blob; SHA256 digest); message: ""}
