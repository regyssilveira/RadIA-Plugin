# Revisão automática ao salvar

Ative **Ferramentas > RadIA > Review automatically on save** para a sessão atual da IDE. Depois de cada save da
unit ativa, o RadIA analisa em background até 20 achados objetivos, como linhas acima de 120 caracteres, espaços
finais e marcadores TODO/FIXME. Os achados aparecem na revisão inline e podem ser revisados ou descartados.

O fluxo é opt-in, não bloqueia o save e não altera o código automaticamente. Desative o mesmo item do menu para
interromper novas análises.
