This document was created by the [PetranWay Autodocumentation Utility](https://bitbucket.org/ChrisCilino/labview-auto-documentation/src/master/).





# Charter

Empty



# Location

C:\NATS Project\NATS Client\NATS Client.lvclass



# Private Data

See the [Class Report Design](https://bitbucket.org/ChrisCilino/labview-auto-documentation/wiki/User%20Documentation/Confluence%20Report%20Printouts/Class) for an explanation of [data name](https://bitbucket.org/ChrisCilino/labview-auto-documentation/wiki/User%20Documentation/Confluence%20Report%20Printouts/Class#markdown-header-private-data-name) and [type](https://bitbucket.org/ChrisCilino/labview-auto-documentation/wiki/User%20Documentation/Confluence%20Report%20Printouts/Class#markdown-header-private-data-type) syntax.

|Name|Description|Data Type|
|-|-|-|
|async stop notifier*||TypedRefNum|
|async stop notifier*.||Boolean|
|nats connection{}||TypeDef "nats connection": Cluster|
|nats connection{}.connection ID||RefNum|
|nats connection{}.server INFO||String|
|nats connection{}.timeout ms||I32|
|nats connection{}.verbose?||Boolean|
|nats connection{}.server headers?||Boolean|
|nats connection{}.client headers?||Boolean|
|subscriptions queue*||TypedRefNum|
|subscriptions queue*.subscription queue{}||TypeDef "subscription queue": Cluster|
|subscriptions queue*.subscription queue{}.action||TypeDef "subscription actions": Enum (U16):   {0 : sub   1 : unsub}|
|subscriptions queue*.subscription queue{}.subscription||LabVIEW Class of type "NATS Subscription.lvlib:NATS Subscription.lvclass"|
|async vi||VIRefNum|




# Members

|Member Name|Scope|Dynamic Dispatch|Must Override|Must Use Parent Implementation|Description \ Prototype|
|-|-|-|-|-|-|
|register subscriber|community|FALSE|FALSE|FALSE|<img src="/docs/Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/register%20subscriberc.png" alt="register subscriberc.png" width="313" hieght="47" />|
|| | | | ||
|| | | | ||
|remove subscriber|community|FALSE|FALSE|FALSE|<img src="/docs/Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/remove%20subscriberc.png" alt="remove subscriberc.png" width="313" hieght="47" />|
|| | | | ||
|| | | | ||
|client|private|FALSE|FALSE|FALSE|<img src="/docs/Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/clientc.png" alt="clientc.png" width="281" hieght="63" />|
|| | | | |Reads a message from the NATS server.|
|| | | | ||
|NATS Client Publish|public|FALSE|FALSE|FALSE|<img src="/docs/Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/NATS%20Client%20Publishc.png" alt="NATS Client Publishc.png" width="329" hieght="63" />|
|| | | | ||
|| | | | ||
|NATS Client request|public|FALSE|FALSE|FALSE|<img src="/docs/Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/NATS%20Client%20requestc.png" alt="NATS Client requestc.png" width="292" hieght="95" />|
|| | | | ||
|| | | | ||
|NATS Client start|public|FALSE|FALSE|FALSE|<img src="/docs/Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/NATS%20Client%20startc.png" alt="NATS Client startc.png" width="313" hieght="79" />|
|| | | | ||
|| | | | ||
|NATS Client stop|public|FALSE|FALSE|FALSE|<img src="/docs/Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/NATS%20Client%20stopc.png" alt="NATS Client stopc.png" width="237" hieght="39" />|
|| | | | |Reads a message from the NATS server.|
|| | | | ||
|get async stop notifier|private|FALSE|FALSE|FALSE|<img src="/docs/Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/get%20async%20stop%20notifierc.png" alt="get async stop notifierc.png" width="301" hieght="47" />|
|| | | | ||
|| | | | ||
|set async stop notifier|private|FALSE|FALSE|FALSE|<img src="/docs/Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/set%20async%20stop%20notifierc.png" alt="set async stop notifierc.png" width="312" hieght="47" />|
|| | | | ||
|| | | | ||
|get async vi|private|FALSE|FALSE|FALSE|<img src="/docs/Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/get%20async%20vic.png" alt="get async vic.png" width="289" hieght="47" />|
|| | | | ||
|| | | | ||
|set async vi|private|FALSE|FALSE|FALSE|<img src="/docs/Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/set%20async%20vic.png" alt="set async vic.png" width="289" hieght="47" />|
|| | | | ||
|| | | | ||
|get nats connection|public|FALSE|FALSE|FALSE|<img src="/docs/Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/get%20nats%20connectionc.png" alt="get nats connectionc.png" width="289" hieght="47" />|
|| | | | ||
|| | | | ||
|set nats connection|public|FALSE|FALSE|FALSE|<img src="/docs/Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/set%20nats%20connectionc.png" alt="set nats connectionc.png" width="298" hieght="47" />|
|| | | | ||
|| | | | ||
|get subscriptions queue|public|FALSE|FALSE|FALSE|<img src="/docs/Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/get%20subscriptions%20queuec.png" alt="get subscriptions queuec.png" width="310" hieght="47" />|
|| | | | ||
|| | | | ||
|set subscriptions queue|public|FALSE|FALSE|FALSE|<img src="/docs/Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/set%20subscriptions%20queuec.png" alt="set subscriptions queuec.png" width="320" hieght="47" />|
|| | | | ||
|| | | | ||
|subscription actions|community|FALSE|FALSE|FALSE|<img src="/docs/Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/subscription%20actionsc.png" alt="subscription actionsc.png" width="32" hieght="32" />|
|| | | | ||
|| | | | ||
|subscription queue|community|FALSE|FALSE|FALSE|<img src="/docs/Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/subscription%20queuec.png" alt="subscription queuec.png" width="32" hieght="32" />|
|| | | | ||
|| | | | ||


