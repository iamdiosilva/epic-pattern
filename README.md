# Epic STL Organizer

Aplicativo Flutter para Windows para organizar coleções de STL da Epic Miniatures.

## Recursos
- Varredura recursiva de arquivos STL em uma pasta escolhida.
- Prefixa `_` no nome de STLs elegíveis (sem duplicar prefixos).
- Move arquivos contendo `[One Piece]` para uma pasta de backup recuperável.
- Substitui bases STL locais por versões da pasta `Bases` **somente quando os nomes são exatamente iguais**; casos sem correspondência ficam intactos.
- Prévia das alterações e seleção de cada operação antes de executar.
- Backups de todos os arquivos substituídos ou removidos, em `.epic_pattern_backups`.
- Registro de execução e mensagem de erro por arquivo.

## Executar no Windows

Instale o [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) e o Visual Studio com **Desktop development with C++**.

```powershell
git clone https://github.com/iamdiosilva/epic-pattern.git
cd epic-pattern
flutter create --platforms=windows .
flutter pub get
flutter run -d windows
```

O repositório contém a aplicação Dart e as dependências; `flutter create --platforms=windows .` gera os arquivos de projeto nativos da versão Flutter instalada.

## Substituição de bases

Selecione a pasta da coleção (por exemplo `D:\Epic Miniatures`) e escolha a pasta com **bases suportadas** (padrão: `D:\Epic Miniatures\Bases`). O programa procura STLs de base em subpastas de modelos, com nome de arquivo idêntico ao de um STL na pasta de bases suportadas, ignorando o próprio diretório de templates. Não faz correspondência aproximada entre tamanhos, porque isso poderia aplicar uma base incorreta.

## Segurança

A prévia é obrigatória. Ao executar, o programa move arquivos substituídos e arquivos `[One Piece]` para um diretório de backup, permitindo recuperação manual. Os arquivos de backup não são escaneados. A renomeação para quando o nome final já existe, sem sobrescrevê-lo.

**Observação:** esta primeira versão implementa a lógica de correspondência de bases por nome; ajuste as regras quando houver exemplos reais das bases sem e com suporte.
