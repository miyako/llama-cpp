property _EOL; _name; _platform; _executableName; _executablePath : Text
property _executableFile : 4D:C1709.File
property _currentDirectory : 4D:C1709.Folder
property _controller : cs:C1710._CLI_Controller

Class constructor($executableName : Text; $controller : 4D:C1709.Class)
	
	This:C1470._name:=OB Class:C1730(This:C1470).name
	
	Case of 
		: (Is macOS:C1572)
			This:C1470._platform:="macOS"
			This:C1470._executableName:=$executableName
			This:C1470._EOL:="\n"
		: (Is Windows:C1573)
			This:C1470._platform:="Windows"
			This:C1470._executableName:=$executableName+".exe"
			This:C1470._EOL:="\r\n"
	End case 
	
	This:C1470._currentDirectory:=This:C1470.expand(Folder:C1567("/RESOURCES/bin").folder(This:C1470.platform))
	
	This:C1470._executableFile:=File:C1566(This:C1470.currentDirectory.file(This:C1470.executableName).path)
	
	If (This:C1470._executableFile.exists)
		
		//the executable is in /RESOURCES/bin/{platform}
		
		Case of 
			: (Is macOS:C1572)
				This:C1470._executablePath:=This:C1470.currentDirectory.file(This:C1470.executableName).path
			: (Is Windows:C1573)
				This:C1470._executablePath:=This:C1470.currentDirectory.file(This:C1470.executableName).platformPath
		End case 
		
		This:C1470._chmod()
		
	Else 
		
		//the executable is not in /RESOURCES/bin/{platform} depend on $PATH
		
		This:C1470._executablePath:=This:C1470.executableName
	End if 
	
	If ($controller=Null:C1517)
		This:C1470._controller:=cs:C1710._CLI_Controller.new(This:C1470)  //default controller
	Else 
		This:C1470._controller:=$controller.new(This:C1470)  //custom controller
	End if 
	
Function get name()->$name : Text
	
	$name:=This:C1470._name
	
Function get EOL()->$EOL : Text
	
	$EOL:=This:C1470._EOL
	
Function get executableName()->$executableName : Text
	
	$executableName:=This:C1470._executableName
	
Function get platform()->$platform : Text
	
	$platform:=This:C1470._platform
	
Function get currentDirectory()->$currentDirectory : 4D:C1709.Folder
	
	$currentDirectory:=This:C1470._currentDirectory
	
Function get executablePath()->$executablePath : Text
	
	$executablePath:=This:C1470._executablePath
	
Function get executableFile()->$executableFile : 4D:C1709.File
	
	$executableFile:=This:C1470._executableFile
	
Function get controller()->$controller : cs:C1710._CLI_Controller
	
	$controller:=This:C1470._controller
	
	//MARK:-public methods
	
Function escape($in : Text)->$out : Text
	
	$out:=$in
	
	var $i; $len : Integer
	
	Case of 
		: (Is Windows:C1573)
			
/*
argument escape for cmd.exe; other programs may be incompatible
*/
			
			$shoudQuote:=False:C215
			
			$metacharacters:="&|<>()%^\" "
			
			$len:=Length:C16($metacharacters)
			
			For ($i; 1; $len)
				$metacharacter:=Substring:C12($metacharacters; $i; 1)
				$shoudQuote:=$shoudQuote | (Position:C15($metacharacter; $out; *)#0)
				If ($shoudQuote)
					$i:=$len
				End if 
			End for 
			
			If ($shoudQuote)
				If (Substring:C12($out; Length:C16($out))="\\")
					$out:="\""+$out+"\\\""
				Else 
					$out:="\""+$out+"\""
				End if 
			End if 
			
		: (Is macOS:C1572)
			
/*
argument escape for bash or zsh; other programs may be incompatible
*/
			
			$metacharacters:="\\!\"#$%&'()=~|<>?;*`[] "
			
			For ($i; 1; Length:C16($metacharacters))
				$metacharacter:=Substring:C12($metacharacters; $i; 1)
				$out:=Replace string:C233($out; $metacharacter; "\\"+$metacharacter; *)
			End for 
			
	End case 
	
Function expand($in : Object)->$out : Object
	
	$out:=OB Class:C1730($in).new($in.platformPath; fk platform path:K87:2)
	
Function quote($in : Text)->$out : Text
	
	$out:="\""+$in+"\""
	
	//MARK:-private methods
	
Function _chmod()
	
	If (Is macOS:C1572)
		//If (Application type=4D Remote mode)
		SET ENVIRONMENT VARIABLE:C812("_4D_OPTION_CURRENT_DIRECTORY"; This:C1470.currentDirectory.platformPath)
		SET ENVIRONMENT VARIABLE:C812("_4D_OPTION_BLOCKING_EXTERNAL_PROCESS"; "true")
		LAUNCH EXTERNAL PROCESS:C811("chmod +x "+This:C1470.executableName)
		//End if 
	End if 