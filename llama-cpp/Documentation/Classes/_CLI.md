# _CLI

`_CLI` is the base class to implement console program proxies. Extend this class to implement a specific command line interface.

## .new() 

**.new**($executableName : Text) : cs._CLI

Pass the name of the CLI agent. It should be placed in the following location:

```
/RESOURCES/bin/{macOS|Windows}/
```

The constructor defines the following properties:

|Property|Type|Description|
|:-|:-|:-|
|controller|cs._CLI_Controller|read-only|
|currentDirectory|4D.Folder|read-only|
|EOL|Text|read-only|
|executableFile|4D.File|read-only|
|executableName|Text|read-only|
|executablePath|Text|read-only|
|name|Text|read-only|
|platform|Text|read-only|

The class is intended to be subclassed. `.name` returns the value `OB Class(This).name` which is the name of the extended class, not this class.

## .escape()

**.escape()**($in : Text) : Text

Add double quotes on each sides of a string that contains metacharacters on Windows, except when the last character is a backslash in which case the backslash is escaped with a backslash before the whole string is quoted. Escape metacharacters on Mac. Not all CLI agent respect this type of escaping.

## .quote()

**.quote**($in : Text) : Text

Simply add double quotes on each sides of a string. Some CLI agent prefer this type of escaping.

## ._chmod()

**._chmod()**

Executable files transferred from server to client in `/RESOURCES/` are copies as regular documents and missing the UNIX executable bit. This internal function is internally called once in the constructor to make sure that the CLI agent is ready to run on a Mac client.  
