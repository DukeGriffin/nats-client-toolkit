This document was created by the [PetranWay Autodocumentation Utility](https://bitbucket.org/ChrisCilino/labview-auto-documentation/src/master/).





# Charter

Empty



# Location

C:\NATS Project\NATS Subscription\NATS Subscription.lvclass



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




# Members

|Member Name|Scope|Dynamic Dispatch|Must Override|Must Use Parent Implementation|Description \ Prototype|
|-|-|-|-|-|-|
|receive|public|TRUE|FALSE|FALSE|<img src="/Images/NATS-Subscription.lvlib--NATS-Subscription.lvclass-Class-Documentation/receivec.png" alt="receivec.png" width="340" hieght="47" />|
|| | | | ||
|| | | | ||
|start|public|FALSE|FALSE|FALSE|<img src="/Images/NATS-Subscription.lvlib--NATS-Subscription.lvclass-Class-Documentation/startc.png" alt="startc.png" width="290" hieght="47" />|
|| | | | ||
|| | | | ||
|stop|public|FALSE|FALSE|FALSE|<img src="/Images/NATS-Subscription.lvlib--NATS-Subscription.lvclass-Class-Documentation/stopc.png" alt="stopc.png" width="274" hieght="47" />|
|| | | | ||
|| | | | ||
|wait on subscription|public|TRUE|FALSE|FALSE|<img src="/Images/NATS-Subscription.lvlib--NATS-Subscription.lvclass-Class-Documentation/wait%20on%20subscriptionc.png" alt="wait on subscriptionc.png" width="302" hieght="47" />|
|| | | | ||
|| | | | ||
|get id|public|FALSE|FALSE|FALSE|<img src="/Images/NATS-Subscription.lvlib--NATS-Subscription.lvclass-Class-Documentation/get%20idc.png" alt="get idc.png" width="361" hieght="47" />|
|| | | | ||
|| | | | ||
|set id|protected|FALSE|FALSE|FALSE|<img src="/Images/NATS-Subscription.lvlib--NATS-Subscription.lvclass-Class-Documentation/set%20idc.png" alt="set idc.png" width="361" hieght="47" />|
|| | | | ||
|| | | | ||
|get reply queue|public|FALSE|FALSE|FALSE|<img src="/Images/NATS-Subscription.lvlib--NATS-Subscription.lvclass-Class-Documentation/get%20reply%20queuec.png" alt="get reply queuec.png" width="361" hieght="47" />|
|| | | | ||
|| | | | ||
|set reply queue|public|FALSE|FALSE|FALSE|<img src="/Images/NATS-Subscription.lvlib--NATS-Subscription.lvclass-Class-Documentation/set%20reply%20queuec.png" alt="set reply queuec.png" width="361" hieght="47" />|
|| | | | ||
|| | | | ||
|get subject|public|FALSE|FALSE|FALSE|<img src="/Images/NATS-Subscription.lvlib--NATS-Subscription.lvclass-Class-Documentation/get%20subjectc.png" alt="get subjectc.png" width="361" hieght="47" />|
|| | | | ||
|| | | | ||
|set subject|protected|FALSE|FALSE|FALSE|<img src="/Images/NATS-Subscription.lvlib--NATS-Subscription.lvclass-Class-Documentation/set%20subjectc.png" alt="set subjectc.png" width="361" hieght="47" />|
|| | | | ||
|| | | | ||


