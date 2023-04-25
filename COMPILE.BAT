@echo off
if not exist BIN md BIN
if exist p_utils.tpu del p_utils.tpu
if exist p_dosmem.tpu del p_dosmem.tpu
if exist p_graph1.tpu del p_graph1.tpu
if exist p_graph2.tpu del p_graph2.tpu
if exist p_rip.tpu del p_rip.tpu
if exist p_loader.tpu del p_loader.tpu
if exist p_config.tpu del p_config.tpu
if exist p_viewer.tpu del p_viewer.tpu
if exist p_saver.tpu del p_saver.tpu
if exist pv.exe del pv.exe
if exist pv.ini del pv.ini
c:\dev\dos\tp\bin\tpc -Uc:\dev\dos\tp\units -EBIN -B -$G+ pv.pas
