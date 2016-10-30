###Setor externo 
Não está sujeito a taxas. [Adicionar flag de externo ou interno na criaçao dos agentes, aplica taxas se for interno]

#Para organizações   
Produtor de Regras :    
* A troco de numerário produz uma regra (máquina) nova.
* A troco de numerário aumenta os níveis de produção de uma regra (máquina).   
								
Criar tipo 'CreditContract':
* Montante
* Prazo de Pagamento
* Juro
* Montante Vencido
* Client   
#####Mesma estrutura no Bank

Solvência ? Nao emprestar.

Criar variável 'Savings_Investment': (Numerário de com poupança/investimentos de um agente).

Criar tipo 'Bank' que fornece o crédito.
No fim do periodo, percorre se os creditos de contrato e recebe o pagamento com juros do montante.
