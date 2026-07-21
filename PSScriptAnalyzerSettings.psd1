@{
    # PSScriptAnalyzer per setup-pc.ps1. La CI fallisce solo sugli ERRORI (bug
    # veri / errori di parsing); i Warning vengono mostrati ma non bloccano.
    # Escludiamo le regole che vanno contro scelte VOLUTE di questo progetto:
    #  - verbi non "approvati": usiamo verbi italiani (Installa-, Chiedi, ...)
    #    perche' lo script e' pensato per essere letto dagli operatori;
    #  - Write-Host: e' l'interfaccia utente a schermo, voluta;
    #  - ShouldProcess: script interattivo, non un modulo riusabile;
    #  - nomi plurali / Invoke-Expression: usati apposta nei test e nei cataloghi.
    ExcludeRules = @(
        'PSUseApprovedVerbs',
        'PSAvoidUsingWriteHost',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSUseSingularNouns',
        'PSAvoidUsingInvokeExpression',
        'PSAvoidUsingPositionalParameters',
        'PSUseBOMForUnicodeEncodedFile',
        'PSAvoidTrailingWhitespace'
    )
}
