This document was created by the [PetranWay Autodocumentation Utility](https://bitbucket.org/ChrisCilino/labview-auto-documentation/src/master/).





# Charter

Empty



# Location

C:\NATS Project\NATS Core.lvlib

<@>Libraries<@>

<@>Classes<@>



# Members

|Name|Description|Icon|
|-|-|-|
|NATS HPUB|Publishes a message with headers to the NATS server.|<img src="/Images/NATS-Core-Library-Documentation/NATS%20HPUBc.png" alt="NATS HPUBc.png" width="373" hieght="111" />|
|NATS PUB|Publishes a message to the NATS server.|<img src="/Images/NATS-Core-Library-Documentation/NATS%20PUBc.png" alt="NATS PUBc.png" width="373" hieght="95" />|
|Add Version and Language JSON Entries|Adds "version", "headers", and "lang" entries to the JSON string if they are not already present.|<img src="/Images/NATS-Core-Library-Documentation/Add%20Version%20and%20Language%20JSON%20Entriesc.png" alt="Add Version and Language JSON Entriesc.png" width="332" hieght="47" />|
|Check for Authorization|Check if the server is requesting some form of authorization. If so, verify the client has provided some form of authorization regardless of validity.|<img src="/Images/NATS-Core-Library-Documentation/Check%20for%20Authorizationc.png" alt="Check for Authorizationc.png" width="335" hieght="47" />|
|Determine Message Type|Determines the type of message received from the NATS server. Strips off message pre/postamble for type-identified messages when appropriate.|<img src="/Images/NATS-Core-Library-Documentation/Determine%20Message%20Typec.png" alt="Determine Message Typec.png" width="255" hieght="47" />|
|Package Version Constant|Version of the package last built by VI Package Manager. The constant in this VI is automatically updated by the package builder's Pre-Build VI.|<img src="/Images/NATS-Core-Library-Documentation/Package%20Version%20Constantc.png" alt="Package Version Constantc.png" width="165" hieght="35" />|
|Parse MSG|Parses the individual properties specified in the MSG string, not including the as-yet unread payload.|<img src="/Images/NATS-Core-Library-Documentation/Parse%20MSGc.png" alt="Parse MSGc.png" width="295" hieght="63" />|
|PONG|Sends a PONG response to the NATS server.|<img src="/Images/NATS-Core-Library-Documentation/PONGc.png" alt="PONGc.png" width="373" hieght="55" />|
|Set Timeout|If input of timeout is -2 then use the timeout defined in the nats connection input.|<img src="/Images/NATS-Core-Library-Documentation/Set%20Timeoutc.png" alt="Set Timeoutc.png" width="308" hieght="51" />|
|Validate CONNECT|Uses a rudimentary approach to validate the JSON structure and creates the CONNECT message string|<img src="/Images/NATS-Core-Library-Documentation/Validate%20CONNECTc.png" alt="Validate CONNECTc.png" width="332" hieght="63" />|
|NATS CLOSE|Closes the TCP connection to the NATS server.|<img src="/Images/NATS-Core-Library-Documentation/NATS%20CLOSEc.png" alt="NATS CLOSEc.png" width="272" hieght="39" />|
|NATS CONNECT|Sends the CONNECT command to the NATS server. The default message disables verbose mode, a common practice amongst NATS clients written in other languages.|<img src="/Images/NATS-Core-Library-Documentation/NATS%20CONNECTc.png" alt="NATS CONNECTc.png" width="381" hieght="79" />|
|NATS Open TCP|Opens a TCP connection to the NATS server and collects its INFO message.|<img src="/Images/NATS-Core-Library-Documentation/NATS%20Open%20TCPc.png" alt="NATS Open TCPc.png" width="320" hieght="79" />|
|NATS PING|Sends a PING message to the NATS server. Does not read or wait for a PONG response, so the user should perform a NATS Read immediately after calling this function.|<img src="/Images/NATS-Core-Library-Documentation/NATS%20PINGc.png" alt="NATS PINGc.png" width="373" hieght="55" />|
|NATS Publish (Polymorphic)|Publishes a message to the NATS server. The instances of this polymorphic VI allow or disallow the inclusion of headers in a message by selecting between HPUB or PUB, respectively.|<img src="/Images/NATS-Core-Library-Documentation/NATS%20Publish%20_OP_Polymorphic_CP_c.png" alt="NATS Publish (Polymorphic)c.png" width="373" hieght="95" />|
|NATS READ|Reads a message from the NATS server.|<img src="/Images/NATS-Core-Library-Documentation/NATS%20READc.png" alt="NATS READc.png" width="373" hieght="95" />|
|NATS SUB|Subscribes to a NATS subject with the specified subscription ID.|<img src="/Images/NATS-Core-Library-Documentation/NATS%20SUBc.png" alt="NATS SUBc.png" width="373" hieght="95" />|
|NATS UNSUB|Unsubscribes from the specified subscription ID.|<img src="/Images/NATS-Core-Library-Documentation/NATS%20UNSUBc.png" alt="NATS UNSUBc.png" width="393" hieght="79" />|




# Controls

|Name|Description|Icon|
|-|-|-|
|msg type||<img src="/Images/NATS-Core-Library-Documentation/msg%20typec.png" alt="msg typec.png" width="32" hieght="32" />|
|nats connection||<img src="/Images/NATS-Core-Library-Documentation/nats%20connectionc.png" alt="nats connectionc.png" width="32" hieght="32" />|
|nats message||<img src="/Images/NATS-Core-Library-Documentation/nats%20messagec.png" alt="nats messagec.png" width="32" hieght="32" />|


