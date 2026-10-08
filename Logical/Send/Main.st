
PROGRAM _INIT
	
	(* FUB setup *)
	fbAsmSendShuttleDelete.Assembly						:= ADR(gAssembly_1);
	fbAsmSendShuttleDelete.Sector						:= ADR(Sector_Send);
	fbAsmSendShuttleDelete.ProcessPoint_GetData			:= ADR(ProcessPoint_GetData);
	fbAsmSendShuttleDelete.ProcessPoint_DeleteShuttle	:= ADR(ProcessPoint_DeleteShuttle);
	fbAsmSendShuttleDelete.Configuration				:= ADR(Config);
	fbAsmSendShuttleDelete.HandoverDataReceive			:= ADR(HandoverDataFromReceive);
	fbAsmSendShuttleDelete.HandoverDataSendAddress		:= ADR(HandoverDataToReceive);
	fbAsmSendShuttleDelete.HandoverDataSendSize			:= SIZEOF(HandoverDataToReceive);
	
	(* Configure for STANDALONE simulation *)
	Config.LoggingMode									:= tshLOGGING_DEBUGGING;
	Config.Simulation.ModeForArSim						:= tshSIM_MODE_STANDALONE;
	Config.Simulation.Velocity							:= 1.0;
	Config.Simulation.Acceleration						:= 10.0;
	Config.Simulation.Deceleration						:= 10.0;
	
END_PROGRAM

PROGRAM _CYCLIC
	
	fbAsmSendShuttleDelete.Enable	:= Enable;
	fbAsmSendShuttleDelete();
	 
END_PROGRAM

PROGRAM _EXIT
	(* Insert code here *)
	 
END_PROGRAM

