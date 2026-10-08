
FUNCTION_BLOCK TSH_AsmReceiveShuttleAdd (*Adds shuttles to the assembly with data from the other assembly and sends them to a target*)
	VAR_INPUT
		Assembly : REFERENCE TO McAssemblyType; (*The assembly reference establishes the connection between the function block and the assembly*) (* *) (*#PAR*)
		Sector : REFERENCE TO McSectorType; (*The sector reference establishes the connection between the function block and the sector*) (* *) (*#PAR*)
		Enable : BOOL; (*The function block is active as long as this input is set*) (* *) (*#PAR*)
		HandoverDataReceiveAddress : UDINT; (*Reference to the variable, which contains the data, the function block receives from the POWERLINK interface*) (* *) (*#PAR*)
		HandoverDataReceiveSize : UDINT; (* Size of pv in byte*) (* *) (*#PAR*)
		HandoverDataSend : REFERENCE TO TshCommReceiveToSendType; (*Reference to the variable, which contains the data, the function block sends to the POWERLINK interface*) (* *) (*#PAR*)
		UserDataAddress : UDINT; (*Reference to pv to provide user data of added shuttle. 0 = no user data is provided, but does not affect transfer*) (* *) (*#PAR*)
		UserDataSize : UDINT; (* Size of the userdata of one shuttle (Same as shuttle stereotype) 0 = no user data is transferred*) (* *) (*#PAR*)
		Configuration : REFERENCE TO TshConfigReceiveType; (*Configuration of the function block*) (* *) (*#PAR*)
		Parameter : REFERENCE TO TshAsmReceiveParType; (*Parameter for the handover*) (* *) (*#PAR*)
		Update : BOOL; (*Update the parameter*) (* *) (*#PAR*)
		StartRecovery : BOOL; (*Start the recovery procedure. Only when "RecoveryNeeded = TRUE"*) (* *) (*#CMD*)
		PauseHandover : BOOL; (*Pause the handover and close the barrier*) (* *) (*#CMD*)
		SimAddShuttle : BOOL; (*Add a shuttle to the system in Simulation mode "STANDALONE"*) (* *) (*#CMD#OPT*)
	END_VAR
	VAR_OUTPUT
		Active : BOOL; (*Function block is active and must continue to be called.*) (* *) (*#PAR*)
		Error : BOOL; (*Execution or handover error*) (* *) (*#PAR*)
		StatusID : DINT; (*Error number*) (* *) (*#PAR*)
		UpdateDone : BOOL; (*Parameter were updated successfully*) (* *) (*#PAR*)
		HandoverReady : BOOL; (*Shuttles can now be transferred*) (* *) (*#CYC*)
		AsmSendInError : BOOL; (*Assembly Send is in error state*) (* *) (*#CYC*)
		RecoveryNeeded : BOOL; (*Recovery is needed, before the handover can be started again*) (* *) (*#CYC*)
		RecoveryDone : BOOL; (*Recovery was performed successful*) (* *) (*#CMD*)
		RecoveryBusy : BOOL; (*Recovery was started and is not finished yet*) (* *) (*#CMD*)
		HandoverPaused : BOOL; (*The handover is paused, so no new shuttles are handed over*) (* *) (*#CMD*)
		Info : TshInfoType; (*Additional information structure*) (* *) (*#CMD*)
	END_VAR
	VAR
		Internal : TshAsmReceiveInternalType; (*Internal data*) (* *) (*#OMIT*)
	END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK TSH_AsmSendShuttleDelete (*Reads shuttle information and triggers an "Add shuttle" event on the other assembly before deleting the shuttle*)
	VAR_INPUT
		Assembly : REFERENCE TO McAssemblyType; (*The assembly reference establishes the connection between the function block and the assembly*) (* *) (*#PAR*)
		Sector : REFERENCE TO McSectorType; (*The sector reference establishes the connection between the function block and the sector*) (* *) (*#PAR*)
		ProcessPoint_GetData : REFERENCE TO McProcessPointType; (*The ProcessPoint reference establishes the connection between the function block and the trigger point*) (* *) (*#PAR*)
		ProcessPoint_DeleteShuttle : REFERENCE TO McProcessPointType; (*The ProcessPoint reference establishes the connection between the function block and the trigger point*) (* *) (*#PAR*)
		Enable : BOOL; (*The function block is active as long as this input is set*) (* *) (*#PAR*)
		HandoverDataReceive : REFERENCE TO TshCommReceiveToSendType; (*Reference to the variable, which contains the data, the function block receives from the POWERLINK interface*) (* *) (*#PAR*)
		HandoverDataSendAddress : UDINT; (*Reference to the variable, which contains the data, the function block sends to the POWERLINK interface*) (* *) (*#PAR*)
		HandoverDataSendSize : UDINT; (* Size of pv in byte*) (* *) (*#PAR*)
		UserDataAddress : UDINT; (*Reference to pv to provide user data of deleted shuttle. 0 = no user data is provided, but does not affect transfer*) (* *) (*#PAR*)
		UserDataSize : UDINT; (* Size of the userdata of one shuttle (Same as shuttle stereotype) 0 = no user data is transferred*) (* *) (*#PAR*)
		Configuration : REFERENCE TO TshConfigSendType; (*Configuration of the function block*) (* *) (*#PAR*)
		StartRecovery : BOOL; (*Start the recovery procedure. Only when "RecoveryNeeded = TRUE"*) (* *) (*#CMD*)
		PauseHandover : BOOL; (*Pause the handover and close the barrier*) (* *) (*#CMD*)
	END_VAR
	VAR_OUTPUT
		Active : BOOL; (*Function block is active and must continue to be called.*) (* *) (*#PAR*)
		Error : BOOL; (*Execution or handover error*) (* *) (*#PAR*)
		StatusID : DINT; (*Error number*) (* *) (*#PAR*)
		HandoverReady : BOOL; (*Shuttles can now be transferred*) (* *) (*#CYC*)
		AsmReceiveInError : BOOL; (*Assembly Receive is in error state*) (* *) (*#CYC*)
		RecoveryNeeded : BOOL; (*Recovery is needed, before the handover can be started again*) (* *) (*#CYC*)
		RecoveryDone : BOOL; (*Recovery was performed successful*) (* *) (*#CMD*)
		RecoveryBusy : BOOL; (*Recovery was started and is not finished yet*) (* *) (*#CMD*)
		HandoverPaused : BOOL; (*The handover is paused, so no new shuttles are handed over*) (* *) (*#CMD*)
		Info : TshInfoType; (*Additional information structure*) (* *) (*#CMD*)
	END_VAR
	VAR
		Internal : TshAsmSendInternalType; (*Internal data*) (* *) (*#OMIT*)
	END_VAR
END_FUNCTION_BLOCK
