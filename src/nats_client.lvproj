<?xml version='1.0' encoding='UTF-8'?>
<Project Type="Project" LVVersion="20008000">
	<Property Name="NI.LV.All.SaveVersion" Type="Str">20.0</Property>
	<Property Name="NI.LV.All.SourceOnly" Type="Bool">true</Property>
	<Property Name="NI.Project.Description" Type="Str"></Property>
	<Item Name="My Computer" Type="My Computer">
		<Property Name="server.app.propertiesEnabled" Type="Bool">true</Property>
		<Property Name="server.control.propertiesEnabled" Type="Bool">true</Property>
		<Property Name="server.tcp.enabled" Type="Bool">false</Property>
		<Property Name="server.tcp.port" Type="Int">0</Property>
		<Property Name="server.tcp.serviceName" Type="Str">My Computer/VI Server</Property>
		<Property Name="server.tcp.serviceName.default" Type="Str">My Computer/VI Server</Property>
		<Property Name="server.vi.callsEnabled" Type="Bool">true</Property>
		<Property Name="server.vi.propertiesEnabled" Type="Bool">true</Property>
		<Property Name="specify.custom.address" Type="Bool">false</Property>
		<Item Name="examples" Type="Folder">
			<Item Name="Pub-Sub Example.vi" Type="VI" URL="../examples/Pub-Sub Example.vi"/>
			<Item Name="Publisher.vi" Type="VI" URL="../examples/Publisher.vi"/>
			<Item Name="Request-Response Example.vi" Type="VI" URL="../examples/Request-Response Example.vi"/>
			<Item Name="Requester.vi" Type="VI" URL="../examples/Requester.vi"/>
			<Item Name="Responder.vi" Type="VI" URL="../examples/Responder.vi"/>
			<Item Name="Subscriber.vi" Type="VI" URL="../examples/Subscriber.vi"/>
		</Item>
		<Item Name="test" Type="Folder">
			<Item Name="tests" Type="Folder">
				<Item Name="Client Subscription Integration Test.vi" Type="VI" URL="../../test/tests/Client Subscription Integration Test.vi"/>
				<Item Name="request response test.vi" Type="VI" URL="../../test/tests/request response test.vi"/>
			</Item>
			<Item Name="caraya test runner.vi" Type="VI" URL="../../test/caraya test runner.vi"/>
		</Item>
		<Item Name="LICENSE" Type="Document" URL="../../LICENSE"/>
		<Item Name="nat.lv.viancfg" Type="Document" URL="../../nat.lv.viancfg"/>
		<Item Name="NATS Client.lvlib" Type="Library" URL="../NATS Client/NATS Client.lvlib"/>
		<Item Name="NATS Infrastructure.lvlib" Type="Library" URL="../NATS Infrastructure/NATS Infrastructure.lvlib"/>
		<Item Name="NATS Subscription.lvlib" Type="Library" URL="../NATS Subscription/NATS Subscription.lvlib"/>
		<Item Name="README.md" Type="Document" URL="../../README.md"/>
		<Item Name="Dependencies" Type="Dependencies"/>
		<Item Name="Build Specifications" Type="Build"/>
	</Item>
</Project>
