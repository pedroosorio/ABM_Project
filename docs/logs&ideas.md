###Setor externo 
N�o est� sujeito a taxas. [Adicionar flag de externo ou interno na cria�ao dos agentes, aplica taxas se for interno]

#Para organiza��es   
Produtor de Regras :    
* A troco de numer�rio produz uma regra (m�quina) nova.
* A troco de numer�rio aumenta os n�veis de produ��o de uma regra (m�quina).   
								
Criar tipo 'CreditContract':
* Montante
* Prazo de Pagamento
* Juro
* Montante Vencido
* Client   
#####Mesma estrutura no Bank

Solv�ncia ? Nao emprestar.

Criar vari�vel 'Savings_Investment': (Numer�rio de com poupan�a/investimentos de um agente).

Criar tipo 'Bank' que fornece o cr�dito.
No fim do periodo, percorre se os creditos de contrato e recebe o pagamento com juros do montante.
