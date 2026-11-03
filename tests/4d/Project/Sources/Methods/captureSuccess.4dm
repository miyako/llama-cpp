#DECLARE($state : Object; $receiver : Object; $options : Object; $models : Object)
$state.successCallbacks+=1
$receiver.fixtureReceiverTag:="success"
$options.fixtureCallbackOption:="success"
$state.successArgumentsMatch:=($models.models.length=1)
