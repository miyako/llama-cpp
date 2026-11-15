property fixtureReceiverTag : Text
Class extends _Model

Class constructor($event : cs.event.event)
	Super(8080; cs.event.huggingfaces.new([]); {}; Formula(Null); (Count parameters=0) ? cs.event.event.new() : $event)

Function download()
	// Stage fixture records before invoking the production download method.

Function runDownloads()
	Super.download()
