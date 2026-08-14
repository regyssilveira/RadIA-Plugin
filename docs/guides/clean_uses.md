# Clean Uses

Peça ao agente para limpar os imports da unit ativa. `PrepareCleanUses` consulta a API pública indexada do
projeto e prepara uma preview; nenhuma alteração ocorre nessa etapa. O analisador preserva cláusulas com
condicionais, referências qualificadas, units externas ou sem fonte verificável e units com
`initialization`/`finalization`.

Revise os candidatos e o conteúdo proposto. A aplicação usa `ApplyPatch`, exige consentimento, valida a revisão
do buffer e pode ser desfeita com `RevertPatch`. Execute o build depois da aplicação.
