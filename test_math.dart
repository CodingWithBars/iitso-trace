void main() {
  double sanctionAmount = 50.0;
  double totalHours = 4.0;
  double missedHours = 31.0 / 60.0;
  
  double amount = (missedHours / totalHours) * sanctionAmount;
  print('Raw amount: $amount');
  
  double rounded = (amount / 5.0).round() * 5.0;
  print('Rounded amount: $rounded');
}