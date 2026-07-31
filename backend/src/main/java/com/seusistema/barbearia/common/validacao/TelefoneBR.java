package com.seusistema.barbearia.common.validacao;

public final class TelefoneBR {

    private TelefoneBR() {}

    public static String normalizar(String telefone) {
        return telefone == null ? "" : telefone.replaceAll("\\D", "");
    }

    public static boolean valido(String normalizado) {
        return normalizado.length() == 10 || normalizado.length() == 11;
    }
}
