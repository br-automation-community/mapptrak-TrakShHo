
PROGRAM _INIT
	
	(* FUB setup *)
	fbAsmReceiveShuttleAdd.Assembly						:= ADR(gAssembly_1);
	fbAsmReceiveShuttleAdd.Sector						:= ADR(Sector_Receive);
	fbAsmReceiveShuttleAdd.Configuration				:= ADR(Config);
	fbAsmReceiveShuttleAdd.Parameter					:= ADR(Parameter);
	fbAsmReceiveShuttleAdd.HandoverDataReceiveAddress	:= ADR(HandoverDataFromSend);
	fbAsmReceiveShuttleAdd.HandoverDataReceiveSize		:= SIZEOF(HandoverDataFromSend);
	fbAsmReceiveShuttleAdd.HandoverDataSend				:= ADR(HandoverDataToSend);
	
	(* Configure for STANDALONE simulation *)
	Config.Movement.Velocity							:= 1.0;
	Config.Movement.Acceleration						:= 10.0;
	Config.Movement.Deceleration						:= 10.0;
	Config.LoggingMode									:= tshLOGGING_DEBUGGING;
	Config.Simulation.ModeForArSim						:= tshSIM_MODE_STANDALONE;
	
	(* Configure Parameter *)
	Parameter.Target.Sector								:= Sector_Parking;
	Parameter.Target.Position							:= 0.1;
	Parameter.Target.Velocity							:= 1.0;
	Parameter.Target.Acceleration						:= 10.0;
	Parameter.Target.Deceleration						:= 10.0;
	Parameter.Target.StartDirection						:= mcDIR_POSITIVE;
	Parameter.Target.EndDirection						:= mcDIR_UNDEFINED;
	Parameter.Target.ShuttleOrientation					:= mcDIR_UNDEFINED;
	Parameter.CatchPosition								:= 0.05;
	Parameter.ShuttleSize.ExtendToFront					:= 0.025;
	Parameter.ShuttleSize.ExtendToBack					:= 0.025;
	Parameter.ShuttleSize.Width							:= 0.04;
	Parameter.ShuttleSize.EnableResize					:= tshSHUTTLE_RESIZE_DISABLE;
	Parameter.AutoPause.EnableHandoverAutoPause			:= tshHANDOVER_AUTO_PAUSE_DISABLE;
	
END_PROGRAM

PROGRAM _CYCLIC
	
	fbAsmReceiveShuttleAdd.Enable	:= Enable;
	fbAsmReceiveShuttleAdd();
	
END_PROGRAM

PROGRAM _EXIT
	(* Insert code here *)
	 
END_PROGRAM

