Class constructor($class : 4D.Class)
	var __calls__ : Integer

Function start($port : Integer; $options : Object)
	__calls__+=1

Function get calls() : Integer
	return __calls__
