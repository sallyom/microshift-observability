import time
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import (
    ConsoleSpanExporter,
    SimpleSpanProcessor,
)
from opentelemetry.sdk.metrics import Counter, MeterProvider
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.prometheus import PrometheusMetricsExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from flask import Flask

# Initialize a Flask app
app = Flask(__name__)

# Instrument the Flask app with OpenTelemetry
FlaskInstrumentor().instrument_app(app)

# Set up a tracer
tracer_provider = TracerProvider()
trace.set_tracer_provider(tracer_provider)
span_processor = SimpleSpanProcessor(ConsoleSpanExporter())
tracer_provider.add_span_processor(span_processor)

# Set up a meter
meter_provider = MeterProvider()
metric_exporter = PrometheusMetricsExporter(endpoint="http://localhost:9090/metrics/")
meter_provider.start_pipeline(meter_exporter=metric_exporter)

# Define a counter metric
counter = meter_provider.get_meter(__name__).create_counter(
    "requests",
    "Number of requests",
    "requests",
)

# Set up an OTLP trace exporter
otlp_exporter = OTLPSpanExporter(endpoint="localhost:4317")
span_processor.add_span_exporter(otlp_exporter)

# Define a route for the Flask app
@app.route("/")
def hello():
    # Increment the counter metric
    counter.add(1)

    # Start a new span for the request
    with tracer_provider.get_tracer(__name__).start_as_current_span("hello"):
        # Simulate a delay
        time.sleep(1)

    return "Hello, World!"

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=8080)
