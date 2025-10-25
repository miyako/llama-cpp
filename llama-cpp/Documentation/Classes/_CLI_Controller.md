# _CLI_Controller

`_CLI_Controller` is the base class for `_CLI` controllers. Extend this class to control a specific console program.

## .new() 

**.new**($CLI : cs._CLI) : cs._CLI_Controller

The constructor should not be called directly. It is invoked when a `_CLI` is instantiated.

You can over-ride the following properties:

|Property|Type|Description|
|:-|:-|:-|
|currentDirectory|4D.Folder||
|dataType|Text||
|encoding|Text||
|hideWindow|Boolean||
|onData|4D.Function||
|onDataError|4D.Function||
|onError|4D.Function||
|onResponse|4D.Function||
|onTerminate|4D.Function||
|timeout|Integer||
|variables|Object||

The constructor defines the following properties:

|Property|Type|Description|
|:-|:-|:-|
|commands|Collection|read-only|
|complete|Boolean|read-only|
|instance|cs._CLI|read-only|
|worker|4D.SystemWorker|read-only|

## .execute() 

**.execute**($command : Variant)

Execute one or more commands sequentially. Pass either a text or a collection of text. Subsequent calls to `.execute()` will add the new command to the task queue if an assoicaited worker is already running or else launch a new worker. Private callback functions intecept the `onResponse` and `onTerminate` events during exection to manage to task queue. All custom event hooks, including `onResponse` and `onTerminate` are invoked. Test `This.complete` to know if the event is the last in queue. 

## .terminate() 

**.terminate**()

Clear the task queue and abort the running system worker.
