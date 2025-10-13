FROM dart:stable

# Directorio de trabajo
WORKDIR /app

# Copia solo los archivos de configuración primero (para caché eficiente)
COPY pubspec.yaml pubspec.lock* ./

# Instala dependencias
RUN dart pub get

# Copia el resto del código
COPY . .

# Expone el puerto
EXPOSE 8080

# Ejecuta la app
CMD ["dart", "bin/server.dart"]