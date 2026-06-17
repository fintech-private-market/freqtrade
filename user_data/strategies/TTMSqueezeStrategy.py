# pragma pylint: disable=missing-docstring, invalid-name, pointless-string-statement
from pandas import DataFrame
import talib.abstract as ta
from technical import qtpylib
from freqtrade.strategy import IStrategy

class TTMSqueezeStrategy(IStrategy):
    INTERFACE_VERSION = 3

    # ==================== CONFIGURAÇÕES BÁSICAS ====================
    can_short = True                    # Ativa short (recomendado para BTC)
    timeframe = '4h'                    # Melhor para BTC (pode testar 1h ou daily)
    startup_candle_count: int = 250

    # ROI e Stoploss
    minimal_roi = {"0": 0.04, "60": 0.02, "120": 0.01}
    stoploss = -0.08                    # -8% fixo (ajuste conforme risco)
    trailing_stop = True
    trailing_stop_positive = 0.015
    trailing_stop_positive_offset = 0.03
    trailing_only_offset_is_reached = True

    # ==================== POPULATE INDICATORS ====================
    def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        # Bollinger Bands (20, 2)
        bollinger = qtpylib.bollinger_bands(qtpylib.typical_price(dataframe), window=20, stds=2)
        dataframe['bb_lower'] = bollinger['lower']
        dataframe['bb_middle'] = bollinger['mid']
        dataframe['bb_upper'] = bollinger['upper']

        # Keltner Channels (20, 1.5) - padrão TTM
        keltner = qtpylib.keltner_channel(dataframe, window=20, atrs=1.5)
        dataframe['kc_lower'] = keltner['lower']
        dataframe['kc_middle'] = keltner['mid']
        dataframe['kc_upper'] = keltner['upper']

        # Squeeze Detection (verdadeiro quando BB está dentro do KC)
        dataframe['squeeze_on'] = (
            (dataframe['bb_upper'] <= dataframe['kc_upper']) &
            (dataframe['bb_lower'] >= dataframe['kc_lower'])
        )

        # Momentum (aproximação do LazyBear / TTM)
        dataframe['momentum'] = ta.LINEARREG(dataframe['close'] - dataframe['close'].shift(10), timeperiod=10)

        # Filtro de tendência maior (EMA 200)
        dataframe['ema200'] = ta.EMA(dataframe, timeperiod=200)

        # Volume médio
        dataframe['avg_volume'] = dataframe['volume'].rolling(20).mean()

        return dataframe

    # ==================== ENTRY TREND (LONG & SHORT) ====================
    def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        # Long Entry
        dataframe.loc[
            (
                # Squeeze acabou de disparar (saiu do aperto)
                (dataframe['squeeze_on'].shift(1) == True) & 
                (dataframe['squeeze_on'] == False) &
                
                # Momentum positivo e crescente
                (dataframe['momentum'] > 0) &
                (dataframe['momentum'] > dataframe['momentum'].shift(1)) &
                
                # Acima da EMA 200 (tendência altista maior)
                (dataframe['close'] > dataframe['ema200']) &
                
                # Volume acima da média (opcional mas recomendado)
                (dataframe['volume'] > dataframe['avg_volume'])
            ),
            'enter_long'] = 1

        # Short Entry
        dataframe.loc[
            (
                # Squeeze acabou de disparar
                (dataframe['squeeze_on'].shift(1) == True) & 
                (dataframe['squeeze_on'] == False) &
                
                # Momentum negativo e decrescente
                (dataframe['momentum'] < 0) &
                (dataframe['momentum'] < dataframe['momentum'].shift(1)) &
                
                # Abaixo da EMA 200 (tendência de baixa maior)
                (dataframe['close'] < dataframe['ema200']) &
                
                # Volume acima da média
                (dataframe['volume'] > dataframe['avg_volume'])
            ),
            'enter_short'] = 1

        return dataframe

    # ==================== EXIT TREND (LONG & SHORT) ====================
    def populate_exit_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        # Saída Long: momentum inverte
        dataframe.loc[
            (
                (dataframe['momentum'] < 0) &
                (dataframe['momentum'].shift(1) > 0)
            ),
            'exit_long'] = 1

        # Saída Short: momentum inverte
        dataframe.loc[
            (
                (dataframe['momentum'] > 0) &
                (dataframe['momentum'].shift(1) < 0)
            ),
            'exit_short'] = 1

        return dataframe