@{
    Severity     = @('Information', 'Error', 'Warning')

    ExcludeRules = @(
        'PSAvoidUsingCmdletAliases',
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSAvoidTrailingWhitespace',
        'PSAvoidUsingWriteHost',
        'PSUseConsistentWhitespace',
        'PSAvoidOverwritingBuiltinCmdlets',
        'PSAvoidGlobalVars',
        'UseSupportsShouldProcess'
    )

    Rules        = @{
        PSUseConsistentWhitespace  = @{
            Enable                          = $true
            CheckInnerBrace                 = $true
            CheckOpenBrace                  = $true
            CheckOpenParen                  = $true
            CheckOperator                   = $true
            CheckPipe                       = $true
            CheckPipeForRedundantWhitespace = $true
            CheckSeparator                  = $true
            CheckParameter                  = $true
        }

        PSUseConsistentIndentation = @{
            Enable              = $true
            IndentationSize     = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            Kind                = 'space'
        }
        
        PSPlaceOpenBrace           = @{
            Enable             = $true
            OnSameLine         = $false
            IgnoreOneLineBlock = $true
            NewLineAfter       = $true
        }

        PSPlaceCloseBrace          = @{
            Enable             = $true
            NoEmptyLineBefore  = $true
            IgnoreOneLineBlock = $true
            NewLineAfter       = $true
        }

        PSAlignAssignmentStatement = @{
            Enable         = $true
            CheckHashtable = $true
        }

        AvoidTrailingWhitespace    = @{
            Enable = $true
        }
    }
}







