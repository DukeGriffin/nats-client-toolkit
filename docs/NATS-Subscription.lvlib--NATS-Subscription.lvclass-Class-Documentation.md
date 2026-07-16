This document was created by the [PetranWay Autodocumentation Utility](https://bitbucket.org/ChrisCilino/labview-auto-documentation/src/master/).


# Charter

Empty

# Location

..\src\NATS Subscription\NATS Subscription.lvclass

# Private Data

See the [Class Report Design](https://bitbucket.org/ChrisCilino/labview-auto-documentation/wiki/User%20Documentation/Confluence%20Report%20Printouts/Class) for an explanation of [data name](https://bitbucket.org/ChrisCilino/labview-auto-documentation/wiki/User%20Documentation/Confluence%20Report%20Printouts/Class#markdown-header-private-data-name) and [type](https://bitbucket.org/ChrisCilino/labview-auto-documentation/wiki/User%20Documentation/Confluence%20Report%20Printouts/Class#markdown-header-private-data-type) syntax.

|Name|Description|Data Type|
|-|-|-|
|id||String|
|subject||String|
|reply queue*||TypedRefNum|
|reply queue*.nats message{}||TypeDef "nats message": Cluster|
|reply queue*.nats message{}.subject||String|
|reply queue*.nats message{}.payload||String|
|reply queue*.nats message{}.sub id||String|
|reply queue*.nats message{}.reply-to||String|
|reply queue*.nats message{}.headers||String|
|reply queue*.nats message{}.type||TypeDef "msg type": Enum (U16):   {0 : Undefined   1 : MSG   2 : HMSG   3 : +OK   4 : PING   5 : PONG   6 : -ERR   7 : INFO}|
|reply queue*.nats message{}.received||AbsTime|
|queue||String|

# Members

|Member Name|Scope|Dynamic Dispatch|Must Override|Must Use Parent Implementation|Description \ Prototype|
|-|-|-|-|-|-|
|Receive Response|community|FALSE|FALSE|FALSE|<img src="Images/NATS-Subscription.lvlib--NATS-Subscription.lvclass-Class-Documentation/Receive%20Responsec.png" alt="Receive Responsec.png" width="340" height="47" />|
|Sub|public|FALSE|FALSE|FALSE|<img src="Images/NATS-Subscription.lvlib--NATS-Subscription.lvclass-Class-Documentation/Subc.png" alt="Subc.png" width="292" height="63" />|
|| | | | |Creates and registers a subscription with the NATS Client.|
|Unsub|public|FALSE|FALSE|FALSE|<img src="Images/NATS-Subscription.lvlib--NATS-Subscription.lvclass-Class-Documentation/Unsubc.png" alt="Unsubc.png" width="320" height="47" />|
|| | | | |Unregisters a subscription with the client.|
|Wait on Response|public|FALSE|FALSE|FALSE|<img src="Images/NATS-Subscription.lvlib--NATS-Subscription.lvclass-Class-Documentation/Wait%20on%20Responsec.png" alt="Wait on Responsec.png" width="302" height="47" />|
|| | | | |Returns the next subscription response.|
|get id|public|FALSE|FALSE|FALSE|<img src="Images/NATS-Subscription.lvlib--NATS-Subscription.lvclass-Class-Documentation/get%20idc.png" alt="get idc.png" width="361" height="47" />|
|set id|private|FALSE|FALSE|FALSE|<img src="Images/NATS-Subscription.lvlib--NATS-Subscription.lvclass-Class-Documentation/set%20idc.png" alt="set idc.png" width="361" height="47" />|
|Get queue|public|FALSE|FALSE|FALSE|<img src="Images/NATS-Subscription.lvlib--NATS-Subscription.lvclass-Class-Documentation/Get%20queuec.png" alt="Get queuec.png" width="361" height="47" />|
|Set queue|private|FALSE|FALSE|FALSE|<img src="Images/NATS-Subscription.lvlib--NATS-Subscription.lvclass-Class-Documentation/Set%20queuec.png" alt="Set queuec.png" width="361" height="47" />|
|get reply queue|public|FALSE|FALSE|FALSE|<img src="Images/NATS-Subscription.lvlib--NATS-Subscription.lvclass-Class-Documentation/get%20reply%20queuec.png" alt="get reply queuec.png" width="361" height="47" />|
|set reply queue|private|FALSE|FALSE|FALSE|<img src="Images/NATS-Subscription.lvlib--NATS-Subscription.lvclass-Class-Documentation/set%20reply%20queuec.png" alt="set reply queuec.png" width="361" height="47" />|
|get subject|public|FALSE|FALSE|FALSE|<img src="Images/NATS-Subscription.lvlib--NATS-Subscription.lvclass-Class-Documentation/get%20subjectc.png" alt="get subjectc.png" width="361" height="47" />|
|set subject|private|FALSE|FALSE|FALSE|<img src="Images/NATS-Subscription.lvlib--NATS-Subscription.lvclass-Class-Documentation/set%20subjectc.png" alt="set subjectc.png" width="361" height="47" />|
