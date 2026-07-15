-- ============================================================================
--  Mia Prima Estensione  ·  Fantasy Grounds Unity  ·  ruleset D&D 5E
-- ----------------------------------------------------------------------------
--  Scheletro di partenza. Mostra i tre agganci fondamentali:
--    1) messaggio in console (per il debug)
--    2) messaggio nella chat (feedback visibile)
--    3) comandi di chat personalizzati (le tue "automazioni")
--
--  Linguaggio: Lua.  API: oggetti globali forniti da Fantasy Grounds
--  (Debug, ChatManager, Comm, DB, CombatManager, ...).
-- ============================================================================


-- onInit() viene chiamata AUTOMATICAMENTE da FG quando l'estensione si carica
-- (perché lo script è registrato con un "name" in extension.xml).
function onInit()
	-- 1) Messaggio nella console tecnica. Apri la console con /console in chat.
	--    È il posto giusto dove stampare informazioni di debug.
	Debug.console("[MiaEstensione] onInit: estensione caricata correttamente");

	-- 2) Messaggio visibile nella finestra di chat (solo lato tuo).
	ChatManager.SystemMessage("Mia Prima Estensione caricata! Prova /ciao oppure /combattenti in chat.");

	-- 3) Registra due comandi di chat. Sono il modo più semplice per
	--    lanciare un'automazione a comando.
	Comm.registerSlashHandler("ciao", onSlashCiao);
	Comm.registerSlashHandler("combattenti", onSlashCombattenti);
end


-- onClose() viene chiamata quando la campagna si chiude. Utile per pulire.
function onClose()
	Debug.console("[MiaEstensione] onClose: estensione scaricata");
end


-- ----------------------------------------------------------------------------
--  Handler del comando:  /ciao   (opzionalmente /ciao <nome>)
--  I comandi ricevono sempre (sCommand, sParams): sParams è il testo dopo il comando.
-- ----------------------------------------------------------------------------
function onSlashCiao(sCommand, sParams)
	if sParams and sParams ~= "" then
		ChatManager.SystemMessage("Ciao, " .. sParams .. "!");
	else
		ChatManager.SystemMessage("Ciao dal tuo scheletro di estensione 5E!");
	end
end


-- ----------------------------------------------------------------------------
--  Handler del comando:  /combattenti
--  Esempio di AUTOMAZIONE VERA: legge il database della campagna e conta
--  quanti combattenti ci sono nel Combat Tracker.
--  CombatManager.CT_LIST è il percorso "combattracker.list" nel database (DB).
-- ----------------------------------------------------------------------------
function onSlashCombattenti(sCommand, sParams)
	local nCount = DB.getChildCount(CombatManager.CT_LIST);
	ChatManager.SystemMessage("Combattenti nel Combat Tracker: " .. nCount);

	-- Vuoi ciclare su ognuno? Ecco il pattern (scommenta per usarlo):
	-- for _, nodeCombatant in pairs(DB.getChildren(CombatManager.CT_LIST)) do
	--     local sName = DB.getValue(nodeCombatant, "name", "?");
	--     Debug.console("Combattente:", sName);
	-- end
end
