---
layout: page
title: Peso e Balanceamento — Suporte
permalink: /peso-balanceamento/suporte
---

*Última atualização: 23 de maio de 2026*

Precisa de ajuda com o **Peso e Balanceamento**? Esta página é o canal oficial de suporte do aplicativo.

## Contato

E-mail: [tiagoharris@gmail.com](mailto:tiagoharris@gmail.com?subject=Suporte%20Peso%20e%20Balanceamento)

Por favor inclua:

- Modelo do dispositivo (ex.: iPhone 15, iPad Pro 11")
- Versão do iOS / iPadOS
- Versão do App (aba **Sobre** dentro do app, ou listagem da App Store)
- Modelo da aeronave e descrição do cálculo que você estava fazendo
- Descrição breve do problema e passos para reproduzi-lo
- Capturas de tela ou gravação de tela, se possível

Buscamos responder em até **2 dias úteis**.

## Aviso importante

Este app é apenas um **auxiliar de cálculo**. Sempre confirme o peso e balanceamento usando o Manual de Operação do Piloto (POH) / Manual de Voo da Aeronave (AFM) oficiais e os registros atualizados da aeronave antes do voo. A biblioteca inicial de aeronaves usa valores publicados aproximados, com finalidade instrucional — revise e ajuste cada perfil contra a documentação real da aeronave e o peso vazio / braço vazio atuais antes de depender do App para um voo de verdade.

## Perguntas frequentes

### O que os cálculos fazem de fato?
O App calcula peso total, momento total e centro de gravidade (CG) a partir do peso vazio e braço vazio da aeronave somados a cada estação carregada. Em seguida verifica se o ponto resultante (CG, peso) cai dentro do envelope certificado da aeronave e reporta **Dentro do envelope**, **Fora do envelope** (à frente, à ré, ou acima do peso), conforme o caso.

### Como adiciono minha própria aeronave?
Abra a aba **Aeronaves** → toque no **+** no canto superior direito. Você pode escolher um modelo inicial da biblioteca embutida (Cessna 152, Cessna 172 N/P/R/S, Piper PA-28-161 / PA-28-181, Piper PA-34-200 Seneca II, Diamond DA-40) e personalizá-lo, ou começar de um perfil em branco. Defina o peso vazio, o braço vazio, o MTOW, as estações (nome, braço, tipo) e os pontos de canto do envelope. Salve quando terminar.

### Os valores iniciais não batem com o POH da minha aeronave. O que mudo?
A biblioteca inicial usa valores aproximados, com finalidade instrucional. Para uma aeronave real, você precisa atualizar pelo menos o **peso vazio** e o **braço vazio** para refletir a pesagem / lista de equipamentos atual registrada para aquela matrícula. Os cantos do envelope e os braços das estações também devem ser conferidos contra o POH do ano e modelo específicos.

### Como edito um perfil de aeronave?
Na aba **Aeronaves**, arraste para a esquerda sobre a aeronave que quer editar e toque em **Editar** (lápis azul). Você pode renomear, mudar peso vazio / braço vazio / MTOW, adicionar ou remover estações, e ajustar os cantos do envelope. Salve para manter as mudanças.

### Como excluo um perfil de aeronave?
Na aba **Aeronaves**, arraste para a esquerda sobre a aeronave e toque em **Excluir** (lixeira vermelha). Aparece um diálogo de confirmação para você não perder dados por acidente.

### O que é uma "estação"?
Uma estação é um ponto fixo de carregamento da aeronave (bancos dianteiros, bancos traseiros, combustível, bagageiro etc.) com braço conhecido em polegadas a partir do datum. Você insere um valor em kg ou lb na tela de carregamento e o App multiplica pelo braço para calcular o momento. Treinadores monomotor normalmente têm de 3 a 5 estações; bimotores leves como o PA-34 Seneca II têm de 6 a 7.

### Minha aeronave tem bagageiros frontal e traseiro separados. Posso modelar os dois?
Sim. Adicione duas estações separadas do tipo **Bagagem**, cada uma com seu próprio braço. O App trata cada estação independentemente.

### Por que meu ponto de carregamento está vermelho / "Fora do envelope"?
O resultado (CG, peso) caiu fora do polígono que você definiu no envelope da aeronave. O selo de status indica qual limite foi violado: *CG muito à frente*, *CG muito à ré*, ou *Acima do peso*. Reduza o peso da estação responsável (normalmente bagageiro à frente / à ré, ou combustível) e recalcule.

### Como funciona o **conversor de Avgas**?
A aba **Conversor** no modo **Avgas** converte entre Litros, Galões US, Galões IMP, kg e lb usando a densidade padrão do 100LL de **0,72 kg/L** a 15 °C. As conversões de volume usam os fatores exatos (3,785411784 L/galão US, 4,54609 L/galão IMP). Os resultados batem com os valores arredondados impressos na maioria das cartas de conversão usadas em aeroclubes, dentro do arredondamento típico de piloto.

### Como exporto um cálculo de carregamento para PDF?
Na tela de **Carregamento** de uma aeronave, toque no ícone de compartilhar no canto superior direito. O App gera um PDF de uma página A4 com a identificação da aeronave, a tabela de carregamento por estação, os totais, o CG, o status dentro/fora do envelope, o gráfico do envelope e o carimbo de data/hora. A tela nativa de compartilhamento abre em seguida para você salvar o arquivo, imprimir, enviar por AirDrop, por e-mail ou por qualquer outro destino.

### O app sincroniza entre meus dispositivos?
Não. O Peso e Balanceamento é intencionalmente **local-first**. Os perfis de aeronave ficam no dispositivo em que você os inseriu. Não há sincronização via iCloud, conta nem backend.

### Como faço backup dos meus perfis de aeronave?
Os dados do App são incluídos em um **Backup do iCloud** ou em um **backup criptografado via Finder/iTunes** padrão do seu dispositivo. Restaurar o backup restaura seus perfis de aeronave.

### Por que o app pediu permissão para me rastrear?
No primeiro lançamento, o iOS exibe o prompt do **App Tracking Transparency** porque o App apresenta anúncios em banner via Google AdMob. Conceder a permissão habilita anúncios personalizados; negar muda para anúncios não personalizados. O App em si não rastreia você independentemente da sua escolha. Você pode mudar a decisão em **Ajustes → Privacidade e Segurança → Rastreamento** a qualquer momento.

### Como peço um reembolso?
O App atualmente é gratuito. Se isso mudar no futuro, os reembolsos da App Store são tratados pela Apple — acesse [reportaproblem.apple.com](https://reportaproblem.apple.com) e selecione a compra.

### O app trava ou congela.
Force o fechamento do App e abra novamente. Se o problema persistir, confirme que o iOS e o App estão atualizados, depois nos envie um e-mail com os detalhes listados no início desta página.

## Privacidade

Veja a [Política de Privacidade](/peso-balanceamento/privacidade) para detalhes sobre quais dados o app coleta e quais ele não coleta.
