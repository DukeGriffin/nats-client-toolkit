This document was created by the [PetranWay Autodocumentation Utility](https://bitbucket.org/ChrisCilino/labview-auto-documentation/src/master/).


# Charter

Empty

# Location

..\src\NATS Client\NATS Client.lvclass

# Private Data

See the [Class Report Design](https://bitbucket.org/ChrisCilino/labview-auto-documentation/wiki/User%20Documentation/Confluence%20Report%20Printouts/Class) for an explanation of [data name](https://bitbucket.org/ChrisCilino/labview-auto-documentation/wiki/User%20Documentation/Confluence%20Report%20Printouts/Class#markdown-header-private-data-name) and [type](https://bitbucket.org/ChrisCilino/labview-auto-documentation/wiki/User%20Documentation/Confluence%20Report%20Printouts/Class#markdown-header-private-data-type) syntax.

|Name|Description|Data Type|
|-|-|-|
|async stop notifier*||TypedRefNum|
|async stop notifier*.||Boolean|
|subscriptions queue*||TypedRefNum|
|subscriptions queue*.subscription queue{}||TypeDef "subscription queue": Cluster|
|subscriptions queue*.subscription queue{}.action||TypeDef "subscription actions": Enum (U16):   {0 : sub   1 : unsub}|
|subscriptions queue*.subscription queue{}.subscription||LabVIEW Class of type "NATS Subscription.lvlib:NATS Subscription.lvclass"|
|NATS Connection*||DVR Reference|
|NATS Connection*.nats connection out{}||TypeDef "nats connection": Cluster|
|NATS Connection*.nats connection out{}.connection ID||RefNum|
|NATS Connection*.nats connection out{}.server INFO||String|
|NATS Connection*.nats connection out{}.timeout ms||I32|
|NATS Connection*.nats connection out{}.verbose?||Boolean|
|NATS Connection*.nats connection out{}.server headers?||Boolean|
|NATS Connection*.nats connection out{}.client headers?||Boolean|
|subscription map*||DVR Reference|
|subscription map*.subs in||TypeDef "Subscription Map": Map|
|error queue*||TypedRefNum|
|error queue*.error out{}|**error in** can accept error information wired from VIs previously called. Use this information to decide if any functionality should be bypassed in the event of errors from other VIs.  Right-click the **error in** control on the front panel and select **Explain Error** or **Explain Warning** from the shortcut menu for more information about the error.|Cluster|
|error queue*.error out{}.status|**status** is TRUE (X) if an error occurred or FALSE (checkmark) to indicate a warning or that no error occurred.  Right-click the **error in** control on the front panel and select **Explain Error** or **Explain Warning** from the shortcut menu for more information about the error.|Boolean|
|error queue*.error out{}.code|**code** is the error or warning code.  Right-click the **error in** control on the front panel and select **Explain Error** or **Explain Warning** from the shortcut menu for more information about the error.|I32|
|error queue*.error out{}.source|**source** describes the origin of the error or warning.  Right-click the **error in** control on the front panel and select **Explain Error** or **Explain Warning** from the shortcut menu for more information about the error.|String|

# Members

|Member Name|Scope|Dynamic Dispatch|Must Override|Must Use Parent Implementation|Description \ Prototype|
|-|-|-|-|-|-|
|Register Sub|community|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/Register%20Subc.png" alt="Register Subc.png" width="313" height="47" />|
|Remove Sub|community|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/Remove%20Subc.png" alt="Remove Subc.png" width="313" height="47" />|
|Async|private|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/Asyncc.png" alt="Asyncc.png" width="206" height="95" />|
|| | | | |Reads a message from the NATS server.|
|Get NATS Connection|private|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/get%20nats%20connectionc.png" alt="Get NATS Connectionc.png" width="378" height="39" />|
|Handle Subscription Requests|private|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/Handle%20Subscription%20Requestsc.png" alt="Handle Subscription Requestsc.png" width="281" height="79" />|
|Reconnect|private|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/Reconnectc.png" alt="Reconnectc.png" width="369" height="47" />|
|Resubscribe Following Reconnect|private|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/Resubscribe%20Following%20Reconnectc.png" alt="Resubscribe Following Reconnectc.png" width="272" height="47" />|
|Set NATS Connection|private|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/set%20nats%20connectionc.png" alt="Set NATS Connectionc.png" width="368" height="47" />|
|Publish|public|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/Publishc.png" alt="Publishc.png" width="329" height="79" />|
|| | | | |Publishes subject through NATS Client.|
|Query Client Connection Status|public|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/Query%20Client%20Connection%20Statusc.png" alt="Query Client Connection Statusc.png" width="262" height="39" />|
|| | | | |Checks if the Client is connected to the NATS server.|
|Query Client Errors|public|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/Query%20Client%20Errorsc.png" alt="Query Client Errorsc.png" width="237" height="39" />|
|| | | | |Return Client asynchronous daemon errors.|
|Request and Wait for Response|public|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/Request%20and%20Wait%20for%20Responsec.png" alt="Request and Wait for Responsec.png" width="292" height="95" />|
|| | | | |Publishes a message and waits for a response with a blocking call.|
|Return All Subscriptions|public|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/Return%20All%20Subscriptionsc.png" alt="Return All Subscriptionsc.png" width="262" height="39" />|
|| | | | |Returns all active subscription objects.|
|Start Client|public|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/Start%20Clientc.png" alt="Start Clientc.png" width="327" height="95" />|
|| | | | |Starts the Client asynchronous daemon. The daemon must be started to use other NATS Client.lvclass methods.|
|Stop Client|public|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/Stop%20Clientc.png" alt="Stop Clientc.png" width="237" height="39" />|
|| | | | |Stops the Client asynchronous daemon.|
|get async stop notifier|private|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/get%20async%20stop%20notifierc.png" alt="get async stop notifierc.png" width="301" height="47" />|
|set async stop notifier|private|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/set%20async%20stop%20notifierc.png" alt="set async stop notifierc.png" width="312" height="47" />|
|Get Connection DVR|private|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/Get%20Connection%20DVRc.png" alt="Get Connection DVRc.png" width="299" height="47" />|
|Set Connection DVR|private|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/Set%20Connection%20DVRc.png" alt="Set Connection DVRc.png" width="307" height="47" />|
|Get error queue|private|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/Get%20error%20queuec.png" alt="Get error queuec.png" width="301" height="47" />|
|Set error queue|private|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/Set%20error%20queuec.png" alt="Set error queuec.png" width="301" height="47" />|
|Get subscription map|private|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/Get%20subscription%20mapc.png" alt="Get subscription mapc.png" width="308" height="47" />|
|Set subscription map|private|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/Set%20subscription%20mapc.png" alt="Set subscription mapc.png" width="304" height="47" />|
|get subscriptions queue|private|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/get%20subscriptions%20queuec.png" alt="get subscriptions queuec.png" width="310" height="47" />|
|set subscriptions queue|private|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/set%20subscriptions%20queuec.png" alt="set subscriptions queuec.png" width="320" height="47" />|
|Reconnect Parameters|community|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/Reconnect%20Parametersc.png" alt="Reconnect Parametersc.png" width="32" height="32" />|
|subscription actions|community|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/subscription%20actionsc.png" alt="subscription actionsc.png" width="32" height="32" />|
|Subscription Map|community|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/Subscription%20Mapc.png" alt="Subscription Mapc.png" width="32" height="32" />|
|subscription queue|community|FALSE|FALSE|FALSE|<img src="Images/NATS-Client.lvlib--NATS-Client.lvclass-Class-Documentation/subscription%20queuec.png" alt="subscription queuec.png" width="32" height="32" />|
