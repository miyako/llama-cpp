#DECLARE($state : Object; $receiver : Object; $options : Object; $error : Object)
$receiver.fixtureReceiverTag:="error"
$options.fixtureCallbackOption:="error"
$state.callbacks.push($error)
