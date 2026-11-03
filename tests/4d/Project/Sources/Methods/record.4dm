#DECLARE($file : 4D.File; $digest : Text; $oid : Text)->$record : Object
$record:={folder: $file.parent; path: $file.fullName; size: 3; oid: $oid; USER: "fixture"; REPO: "offline"; BRANCH: "test"}
If ($digest#"")
	$record.lfs:={oid: $digest}
End if
